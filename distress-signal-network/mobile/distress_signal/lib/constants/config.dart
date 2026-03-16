class Config {
  // Backend URL — UPDATE THIS when ngrok/Railway URL changes
  static const String backendUrl = 'https://bluebit-production.up.railway.app';

  // Source enum strings — MUST match api-contract.json exactly
  // Use ONLY these strings. Never modify them.
  static const String sourceManual       = 'manual';
  static const String sourceZeroTouch    = 'zero-touch';
  static const String sourceIotNode      = 'iot_node';
  static const String sourceSonicCascade = 'sonic_cascade';
  
  // Zero-Touch thresholds
  static const double shakeThresholdG     = 2.7;  // g-force trigger
  static const int    shakeCooldownMs      = 5000; // ms between triggers
  static const String zeroTouchMessage    = 'AUTO-SOS: Device impact detected';

  // Sonic Cascade frequencies (Hz)
  static const double cascadeFreq0        = 18000.0; // '0' bit = 18kHz
  static const double cascadeFreq1        = 20000.0; // '1' bit = 20kHz
  static const double cascadeReverseFreq  = 16500.0; // reverse channel
  static const int    cascadeBitDurationMs = 20;     // ms per bit segment

  // HTTP timeouts
  static const int    apiTimeoutSeconds    = 10;

  // ESP32 simulator node IDs
  static const List<String> simulatorNodeIds = [
    'node-001', 'node-002', 'node-003',
    'node-004', 'node-005', 'node-006',
  ];
}