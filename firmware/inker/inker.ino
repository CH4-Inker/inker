/*
 * Inker — ESP32 Bluetooth (A2DP) audio sink  [DEBUG BUILD]
 * ------------------------------------------------------------
 * Turns the ESP32 into a Bluetooth speaker. Heavy Serial logging so you can
 * see exactly what is happening: pairing, connection, playback, and whether
 * audio bytes are actually arriving.
 *
 * Open Serial Monitor at 115200 baud after flashing.
 *
 * HARDWARE: ORIGINAL ESP32 (WROOM / WROVER) only — needs Classic Bluetooth.
 * OUTPUT:   I2S DAC/amp (MAX98357A / PCM5102). Pins below — change to match.
 * LIBRARY:  "ESP32-A2DP" by pschatzmann (only). Uses built-in ESP_I2S.h
 *           (ESP32 board package >= 3.0.0).
 */

#include "ESP_I2S.h"
#include "BluetoothA2DPSink.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>

const uint8_t I2S_BCLK = 5;    // Audio bit clock
const uint8_t I2S_WS   = 25;   // Word select (LRC)
const uint8_t I2S_DOUT = 26;   // Data out to DAC/amp (DIN)

I2SClass i2s;
BluetoothA2DPSink a2dp_sink(i2s);

// ============================================================
//  BLE control channel (watch -> ESP32 command frames)
// ------------------------------------------------------------
//  The watch (BLE central) writes short "$CMD#" frames here when the user
//  controls playback. Runs alongside A2DP in dual mode (BR/EDR + BLE).
//  UUIDs MUST match ESP32Link.swift on the watch.
// ============================================================
#define CTRL_SERVICE_UUID "0000A100-0000-1000-8000-00805F9B34FB"
#define CTRL_CHAR_UUID    "0000A101-0000-1000-8000-00805F9B34FB"

String g_rxBuffer;   // accumulates bytes until a full "$...#" frame arrives

// Act on one parsed command (payload WITHOUT the $ and #). This is the hook
// where LED animations will later be driven.
void handleCommand(const String& cmd) {
  Serial.printf("[CTRL] command: '%s'\n", cmd.c_str());
  if (cmd == "NEXT")       { /* TODO: LED next */ }
  else if (cmd == "PREV")  { /* TODO: LED prev */ }
  else if (cmd == "PLAY")  { /* TODO: LED play */ }
  else if (cmd == "PAUSE") { /* TODO: LED pause */ }
  else if (cmd.startsWith("VOL:")) {
    int vol = cmd.substring(4).toInt();      // 0..100
    Serial.printf("[CTRL] volume -> %d%%\n", vol);
  } else {
    Serial.printf("[CTRL] unknown command '%s'\n", cmd.c_str());
  }
}

// Pull every complete "$...#" frame out of the running buffer.
void parseFrames() {
  int start = g_rxBuffer.indexOf('$');
  while (start >= 0) {
    int end = g_rxBuffer.indexOf('#', start + 1);
    if (end < 0) break;                       // partial frame — wait for more
    handleCommand(g_rxBuffer.substring(start + 1, end));
    g_rxBuffer = g_rxBuffer.substring(end + 1);
    start = g_rxBuffer.indexOf('$');
  }
  // Drop any garbage before the first '$' so the buffer can't grow unbounded.
  if (start < 0 && g_rxBuffer.length() > 64) g_rxBuffer = "";
}

class CtrlCharCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String v = c->getValue();
    Serial.printf("[CTRL] BLE write received (%d bytes): %s\n", v.length(), v.c_str());
    g_rxBuffer += v;
    parseFrames();
  }
};

// Logs when the watch connects / drops the BLE control link, so you can tell
// from the Serial Monitor whether the channel is even up.
class CtrlServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* s) override {
    Serial.println("[CTRL] >>> watch BLE control link CONNECTED");
  }
  void onDisconnect(BLEServer* s) override {
    Serial.println("[CTRL] <<< watch BLE control link DISCONNECTED — re-advertising");
    BLEDevice::startAdvertising();
  }
};

void startBLEControl() {
  Serial.println("[CTRL] startBLEControl() begin");
  BLEDevice::init("Inker");
  Serial.println("[CTRL] BLEDevice::init done");
  BLEServer* server = BLEDevice::createServer();
  server->setCallbacks(new CtrlServerCallbacks());
  BLEService* service = server->createService(CTRL_SERVICE_UUID);
  BLECharacteristic* ch = service->createCharacteristic(
      CTRL_CHAR_UUID,
      BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR);
  ch->setCallbacks(new CtrlCharCallbacks());
  service->start();

  // A 128-bit UUID (16 B) + the device name won't both fit in the 31-byte
  // advertising packet — that overflow silently drops the service UUID, so a
  // filtered scan on the watch never finds us. Put the UUID in the ADV packet
  // and the name in the SCAN-RESPONSE packet instead.
  BLEAdvertising* adv = BLEDevice::getAdvertising();

  BLEAdvertisementData advData;
  advData.setFlags(0x06);                                // general discoverable, BR/EDR not supported (BLE)
  advData.setCompleteServices(BLEUUID(CTRL_SERVICE_UUID));
  adv->setAdvertisementData(advData);

  BLEAdvertisementData scanResp;
  scanResp.setName("Inker");
  adv->setScanResponseData(scanResp);

  BLEDevice::startAdvertising();
  Serial.println("[CTRL] BLE control service advertising (UUID in adv, name in scan-resp).");
}

// --- State we track for the periodic status line ---
volatile uint32_t g_dataPackets = 0;    // incremented every time audio data arrives
volatile uint32_t g_dataBytes   = 0;
int g_connState = -1;                    // last connection state
int g_audioState = -1;                   // last audio state
unsigned long g_lastStatus = 0;

// ============================================================
//  Callbacks
// ============================================================

// Called whenever the Bluetooth connection state changes.
void connection_state_changed(esp_a2d_connection_state_t state, void* /*ptr*/) {
  g_connState = (int)state;
  Serial.print("[BT] Connection state -> ");
  switch (state) {
    case ESP_A2D_CONNECTION_STATE_DISCONNECTED:
      Serial.println("DISCONNECTED"); break;
    case ESP_A2D_CONNECTION_STATE_CONNECTING:
      Serial.println("CONNECTING..."); break;
    case ESP_A2D_CONNECTION_STATE_CONNECTED:
      Serial.println("CONNECTED  <<< watch is paired!"); break;
    case ESP_A2D_CONNECTION_STATE_DISCONNECTING:
      Serial.println("DISCONNECTING..."); break;
    default:
      Serial.printf("UNKNOWN (%d)\n", (int)state); break;
  }
}

// Called when playback starts / stops / is suspended by the watch.
void audio_state_changed(esp_a2d_audio_state_t state, void* /*ptr*/) {
  g_audioState = (int)state;
  Serial.print("[BT] Audio state -> ");
  if (state == ESP_A2D_AUDIO_STATE_STARTED) {
    Serial.println("STARTED (playing)  <<< audio should be coming out now");
  } else {
    Serial.printf("STOPPED/SUSPENDED (%d)\n", (int)state);
  }
}

// Called every time a chunk of audio data is received. This is the PROOF that
// audio is actually flowing from the watch. We only count here (printing every
// packet would flood the monitor); the count is shown in the status line.
void data_received() {
  g_dataPackets++;
}

// Called when the watch sends track metadata (title, artist, etc.) via AVRCP.
void avrc_metadata(uint8_t id, const uint8_t* text) {
  Serial.printf("[BT] Metadata id=0x%02x : %s\n", id, text);
}

// Called when the watch changes the (AVRCP) volume.
void avrc_volume(int vol) {
  Serial.printf("[BT] AVRCP volume -> %d (0-127)\n", vol);
}

// ============================================================
//  Setup
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println();
  Serial.println("========================================");
  Serial.println(" Inker — A2DP sink booting");
  Serial.println(" FIRMWARE BUILD: A2DP + BLE control");   // <-- if you DON'T see this line, the new firmware didn't flash
  Serial.println("========================================");

  Serial.printf("[I2S] Pins BCLK=%d WS=%d DOUT=%d\n", I2S_BCLK, I2S_WS, I2S_DOUT);
  i2s.setPins(I2S_BCLK, I2S_WS, I2S_DOUT);
  if (!i2s.begin(I2S_MODE_STD, 44100, I2S_DATA_BIT_WIDTH_16BIT,
                 I2S_SLOT_MODE_STEREO, I2S_STD_SLOT_BOTH)) {
    Serial.println("[I2S] FAILED to initialize I2S! Check wiring/pins. Halting.");
    while (1) { delay(1000); }
  }
  Serial.println("[I2S] Initialized OK.");

  // Register all the callbacks BEFORE start().
  a2dp_sink.set_on_connection_state_changed(connection_state_changed);
  a2dp_sink.set_on_audio_state_changed(audio_state_changed);
  a2dp_sink.set_on_data_received(data_received);
  a2dp_sink.set_avrc_metadata_callback(avrc_metadata);
  a2dp_sink.set_on_volumechange(avrc_volume);

  // Bring up BLE first so the controller comes up in dual mode (BR/EDR + BLE),
  // then start A2DP on top. NOTE: A2DP + BLE coexistence is memory-heavy —
  // use a BT-capable partition scheme (Huge APP). If A2DP fails to init, this
  // init order / partition is the first thing to check.
  startBLEControl();

  a2dp_sink.start("Inker");

  Serial.println("[BT] A2DP sink started.");
  Serial.println("[BT] Now on the watch: Settings > Bluetooth > pair 'Inker'.");
  Serial.println("[BT] BLE control channel runs in parallel (app connects automatically).");
  Serial.println("----------------------------------------");
}

// ============================================================
//  Loop — prints a heartbeat status line every 2 seconds
// ============================================================
void loop() {
  unsigned long now = millis();
  if (now - g_lastStatus >= 2000) {
    g_lastStatus = now;

    // Snapshot & reset the packet counter so we see the RATE per 2s window.
    uint32_t packets = g_dataPackets;
    g_dataPackets = 0;

    const char* conn =
      (g_connState == ESP_A2D_CONNECTION_STATE_CONNECTED)     ? "CONNECTED" :
      (g_connState == ESP_A2D_CONNECTION_STATE_CONNECTING)    ? "CONNECTING" :
      (g_connState == ESP_A2D_CONNECTION_STATE_DISCONNECTING) ? "DISCONNECTING" :
      "DISCONNECTED";

    const char* audio =
      (g_audioState == ESP_A2D_AUDIO_STATE_STARTED) ? "PLAYING" : "not playing";

    Serial.printf("[STATUS] conn=%s | audio=%s | data packets last 2s = %lu %s\n",
                  conn, audio, (unsigned long)packets,
                  packets > 0 ? "(audio is flowing!)" : "(no audio bytes)");
  }
  delay(50);
}
