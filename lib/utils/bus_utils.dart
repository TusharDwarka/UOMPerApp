import 'time_utils.dart';

/// Day-type keys used in the bus JSON (also read by the native Android widget).
const busDayKeys = ['weekdays', 'saturdays', 'sundays_public_holidays'];
const busDayLabels = ['Weekdays', 'Saturday', 'Sun / Hol'];

/// 0 = weekdays, 1 = Saturday, 2 = Sunday.
int busDayIndexFor(DateTime date) {
  if (date.weekday == DateTime.sunday) return 2;
  if (date.weekday == DateTime.saturday) return 1;
  return 0;
}

/// Sorts trips by departure and drops exact duplicates. Trips must be kept in
/// order because both the app and the home-screen widget pick the first
/// departure after "now".
List<Map<String, dynamic>> sortTrips(Iterable<dynamic> trips) {
  final seen = <String>{};
  final list = <Map<String, dynamic>>[];
  for (final t in trips) {
    final m = Map<String, dynamic>.from(t as Map);
    final dep = normalizeTime((m['departure'] ?? '').toString());
    if (dep.isEmpty) continue;
    m['departure'] = dep;
    final arr = (m['arrival'] ?? '').toString();
    if (arr.isNotEmpty && !arr.startsWith('~')) m['arrival'] = normalizeTime(arr);
    final key = '$dep|${m['arrival']}|${m['bus_name'] ?? ''}';
    if (seen.add(key)) list.add(m);
  }
  list.sort((a, b) => compareTimes(a['departure'], b['departure']));
  return list;
}

/// Index of the first trip leaving strictly after [nowMinutes], or -1.
int nextTripIndex(List<Map<String, dynamic>> sortedTrips, int nowMinutes) {
  for (var i = 0; i < sortedTrips.length; i++) {
    final m = parseMinutes(sortedTrips[i]['departure']?.toString());
    if (m != null && m > nowMinutes) return i;
  }
  return -1;
}

/// Sorts every schedule of a route in place-safe fashion (returns a copy).
Map<String, dynamic> normalizeRoute(Map<String, dynamic> route) {
  final copy = Map<String, dynamic>.from(route);
  final schedules = Map<String, dynamic>.from((copy['schedules'] as Map?) ?? {});
  for (final key in busDayKeys) {
    schedules[key] = sortTrips((schedules[key] as List?) ?? const []);
  }
  copy['schedules'] = schedules;
  return copy;
}
