/*
 * Interactive Speaker — ESP32 Bluetooth (A2DP) audio sink  [DEBUG BUILD]
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

const uint8_t I2S_BCLK = 5;    // Audio bit clock
const uint8_t I2S_WS   = 25;   // Word select (LRC)
const uint8_t I2S_DOUT = 26;   // Data out to DAC/amp (DIN)

I2SClass i2s;
BluetoothA2DPSink a2dp_sink(i2s);

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
  Serial.println(" Interactive Speaker — A2DP sink booting");
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

  a2dp_sink.start("Interactive Speaker");

  Serial.println("[BT] A2DP sink started.");
  Serial.println("[BT] Now on the watch: Settings > Bluetooth > pair 'Interactive Speaker'.");
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
