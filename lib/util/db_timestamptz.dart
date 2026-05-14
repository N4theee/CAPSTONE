/// Parses PostgreSQL `timestamptz` values from Supabase/PostgREST for display in the
/// device [DateTime.timeZoneName] (local clock).
///
/// PostgREST usually returns an explicit offset or `Z`. If the string has **no**
/// timezone, Dart would interpret it as **local** wall time, which is wrong for
/// UTC-stored `timestamptz` — we append `Z` so the instant is interpreted as UTC
/// before converting to local.
DateTime parseDbTimestamptzToLocal(dynamic value) {
  if (value == null) {
    throw ArgumentError.notNull('value');
  }
  if (value is DateTime) {
    return value.toUtc().toLocal();
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) {
    throw ArgumentError('empty timestamp');
  }
  final normalized = normalizePostgresTimestamptzIso(raw);
  return DateTime.parse(normalized).toLocal();
}

DateTime? tryParseDbTimestamptzToLocal(dynamic value) {
  if (value == null) return null;
  try {
    return parseDbTimestamptzToLocal(value);
  } catch (_) {
    return null;
  }
}

/// Exposed for tests / reuse; normalizes a single ISO-like fragment.
String normalizePostgresTimestamptzIso(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  // Some drivers return `YYYY-MM-DD HH:MM:SS` or `... +00:00` without `T`.
  // We must insert `T` *before* checking for a zone, otherwise `_hasExplicitTimezone`
  // misses offsets and we wrongly append `Z` (e.g. `...+00:00Z` is invalid).
  if (!s.contains('T')) {
    s = s.replaceFirst(RegExp(r'\s+'), 'T');
  }
  if (_hasExplicitTimezone(s)) return s;
  return '${s}Z';
}

bool _hasExplicitTimezone(String s) {
  final t = s.trim();
  if (t.endsWith('Z') || t.endsWith('z')) return true;
  final i = t.indexOf('T');
  if (i < 0) return false;
  // ISO8601 zone appears after the time portion: ...T...±hh[:mm]
  return RegExp(r'[+-]\d{2}').hasMatch(t.substring(i + 1));
}

/// UTC instant on the wire (recommended for `timestamptz` columns).
String utcIsoNowForDb() => DateTime.now().toUtc().toIso8601String();
