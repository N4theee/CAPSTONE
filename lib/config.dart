class AppConfig {
  // ── Supabase ──────────────────────────────────────────────
  static const String supabaseUrl = 'https://ofqbwxdytpjljzbzjlxb.supabase.co';      // paste from Step 4
  static const String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9mcWJ3eGR5dHBqbGp6YnpqbHhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwMDMwMTUsImV4cCI6MjA5MTU3OTAxNX0.1dQb48CxK822rBR8SVvklShGjqrtkSaE-SZ0_fGVcd0';       // paste from Step 4
  

  // RSSI threshold for proximity
  // -60 = very close (1-2m)
  // -70 = medium (3-5m)  ← start here
  // -80 = far (roughly classroom sized)
  // Calibrate on-site because walls and phone models vary.
  static const int rssiThreshold      = -100;
  static const int scanRestartSeconds = 8;

  // BLE service UUID used as professor beacon identifier.
  static const String defaultBeaconUuid =
      '12345678-1234-1234-1234-123456789012';
  static const String defaultBeaconName = 'PROFATTN';
}