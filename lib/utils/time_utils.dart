/// Time helpers shared by the schedule, dashboard, widgets and bus screens.
///
/// Times are stored as "HH:mm" strings. Older data (and AI imports) can
/// contain "9:00", "9.00", "09:00:00" or "9:00 AM", which used to break both
/// string sorting ("9:00" sorted after "10:00") and `int.parse` calls.
library;

/// Parses a clock string into minutes from midnight, or null if unparseable.
/// A leading "~" (approximate bus arrival) is ignored.
int? parseMinutes(String? raw) {
  if (raw == null) return null;
  var s = raw.trim().replaceAll('~', '').toUpperCase();
  if (s.isEmpty) return null;

  var pm = false;
  var am = false;
  if (s.endsWith('PM')) {
    pm = true;
    s = s.substring(0, s.length - 2).trim();
  } else if (s.endsWith('AM')) {
    am = true;
    s = s.substring(0, s.length - 2).trim();
  }

  final parts = s.split(RegExp(r'[:.hH]'));
  final hour = int.tryParse(parts[0].trim());
  if (hour == null) return null;
  final minute = parts.length > 1 && parts[1].trim().isNotEmpty ? int.tryParse(parts[1].trim()) : 0;
  if (minute == null || minute < 0 || minute > 59) return null;

  var h = hour;
  if (pm && h < 12) h += 12;
  if (am && h == 12) h = 0;
  if (h < 0 || h > 24) return null;
  return h * 60 + minute;
}

/// Formats minutes from midnight as "HH:mm".
String formatMinutes(int minutes) {
  final m = minutes % (24 * 60);
  final h = (m ~/ 60).toString().padLeft(2, '0');
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$h:$mm';
}

/// Normalises any accepted clock format to "HH:mm". Unparseable input is
/// returned unchanged so no data is lost.
String normalizeTime(String raw) {
  final m = parseMinutes(raw);
  return m == null ? raw : formatMinutes(m);
}

/// Compares two clock strings chronologically. Unparseable values sort last.
int compareTimes(String a, String b) {
  final ma = parseMinutes(a) ?? 1 << 20;
  final mb = parseMinutes(b) ?? 1 << 20;
  return ma.compareTo(mb);
}

/// "in 5 min", "in 1h 20m".
String formatCountdown(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

bool isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
