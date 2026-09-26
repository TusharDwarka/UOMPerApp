/// Side-by-side layout for overlapping blocks in a day view (like Google
/// Calendar). Previously overlapping classes were drawn on top of each other.
class LaidOutBlock<T> {
  final T item;
  final int start;
  final int end;
  final int lane;
  final int laneCount;
  const LaidOutBlock(this.item, this.start, this.end, this.lane, this.laneCount);
}

List<LaidOutBlock<T>> layoutDayBlocks<T>(
  List<T> items, {
  required int Function(T) startOf,
  required int Function(T) endOf,
}) {
  final sorted = [...items]..sort((a, b) {
      final c = startOf(a).compareTo(startOf(b));
      return c != 0 ? c : endOf(b).compareTo(endOf(a));
    });

  final result = <LaidOutBlock<T>>[];
  var cluster = <(T, int, int, int)>[]; // item, start, end, lane
  var clusterEnd = -1;
  var laneEnds = <int>[];

  void flush() {
    final count = laneEnds.length;
    for (final c in cluster) {
      result.add(LaidOutBlock(c.$1, c.$2, c.$3, c.$4, count));
    }
    cluster = [];
    laneEnds = [];
    clusterEnd = -1;
  }

  for (final item in sorted) {
    final s = startOf(item);
    var e = endOf(item);
    if (e <= s) e = s + 30; // malformed or zero-length: still visible
    if (cluster.isNotEmpty && s >= clusterEnd) flush();

    var lane = laneEnds.indexWhere((end) => end <= s);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(e);
    } else {
      laneEnds[lane] = e;
    }
    cluster.add((item, s, e, lane));
    if (e > clusterEnd) clusterEnd = e;
  }
  flush();
  return result;
}
