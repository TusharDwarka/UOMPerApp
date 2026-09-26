import 'dart:math';

final _rng = Random.secure();
const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// 20-char random id, same shape as a Firestore auto-id. Used as the
/// cross-device identity of every synced record.
String newSyncId() => List.generate(20, (_) => _alphabet[_rng.nextInt(_alphabet.length)]).join();

/// Short human-friendly code for joining groups (no 0/O/1/I confusion).
String newJoinCode({int length = 6}) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return List.generate(length, (_) => chars[_rng.nextInt(chars.length)]).join();
}

/// Stable 31-bit hash for strings. Dart's `String.hashCode` is not guaranteed
/// to be stable across app versions, so notification ids and colours use this.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7fffffff;
  }
  return h;
}
