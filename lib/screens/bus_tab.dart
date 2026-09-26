import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../services/bus_repository.dart';
import '../services/pdf_export.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../utils/bus_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/scroll_time_picker.dart';
import '../widgets/ui.dart';

class BusTab extends StatefulWidget {
  const BusTab({super.key});

  @override
  State<BusTab> createState() => _BusTabState();
}

class _BusTabState extends State<BusTab> {
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = true;
  int _selected = 0;
  int _day = busDayIndexFor(DateTime.now());
  bool _showEarlier = false;
  Timer? _ticker;
  StreamSubscription<Set<String>>? _syncSub;
  final _nextKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _syncSub = context.read<SyncService>().changes.listen((c) {
      if (c.contains('bus')) _load();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final routes = await BusRepository.load();
    final sel = await BusRepository.selectedIndex();
    if (!mounted) return;
    setState(() {
      _routes = routes;
      _selected = routes.isEmpty ? 0 : sel.clamp(0, routes.length - 1);
      _isLoading = false;
    });
  }

  /// Sorts every schedule in place (route maps keep their identity so
  /// callbacks holding a route reference stay valid), then persists + syncs.
  Future<void> _save() async {
    for (final r in _routes) {
      r['schedules'] = normalizeRoute(r)['schedules'];
    }
    setState(() {});
    await BusRepository.save(_routes, context.read<SyncService>());
  }

  Map<String, dynamic>? get _route => _routes.isEmpty ? null : _routes[_selected];

  List<Map<String, dynamic>> get _trips {
    final r = _route;
    if (r == null) return const [];
    final list = (r['schedules']?[busDayKeys[_day]] as List?) ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  bool get _isTodayTab => _day == busDayIndexFor(DateTime.now());

  void _selectRoute(int i) {
    setState(() {
      _selected = i;
      _showEarlier = false;
    });
    BusRepository.setSelectedIndex(i);
  }

  // ───────────── Route actions ─────────────

  // ───────────── Share / import / presets ─────────────

  void _shareRoute() {
    final r = _route;
    if (r == null) return;
    Share.share(BusRepository.shareMessage(r), subject: 'Bus timetable: ${r['location_name']}');
  }

  Future<void> _importRoute() async {
    final text = await showControllerDialog<String>(
      context,
      builder: (ctx, controller) => AlertDialog(
        title: const Text('Import a bus route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste the message a friend shared from their Bus tab (it contains a UOMBUS1: code).'),
            const SizedBox(height: 12),
            TextField(controller: controller, autofocus: true, maxLines: 4, decoration: const InputDecoration(hintText: 'Paste here')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Import')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    final route = BusRepository.decodeRoute(text);
    if (route == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("That doesn't contain a valid bus route code")));
      return;
    }
    _addRoutes([route]);
  }

  Future<void> _addPreset() async {
    final presets = BusRepository.presets;
    final picked = await showChoiceSheet<int>(
      context,
      title: 'Add a ready-made route',
      options: List.generate(presets.length, (i) => i),
      selected: null,
      labelOf: (i) => _shortName(presets[i]['location_name'].toString()),
      subtitleOf: (i) => 'Route ${presets[i]['bus_route']}',
      iconOf: (_) => Icons.directions_bus_rounded,
    );
    if (picked != null) _addRoutes([presets[picked]]);
  }

  Future<void> _addRoutes(List<Map<String, dynamic>> routes) async {
    setState(() {
      _routes.addAll(routes);
      _selected = _routes.length - 1;
    });
    BusRepository.setSelectedIndex(_selected);
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${_shortName(routes.last['location_name'].toString())}')));
    }
  }

  Widget _buildEmpty(Palette p) {
    Widget option(IconData icon, String title, String subtitle, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SoftCard(
            radius: 26,
            onTap: onTap,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
                  child: Icon(icon, color: p.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: p.textPrimary)),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: p.textMuted),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add the buses you take', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w300, color: p.textPrimary)),
          const SizedBox(height: 4),
          Text('Everyone lives somewhere different, so start with your own route.', style: TextStyle(color: p.textSecondary)),
          const SizedBox(height: 18),
          option(Icons.add_road_rounded, 'Create a route', 'Type in the stop and the times', _addRoute),
          option(Icons.download_rounded, 'Import from a friend', 'Paste a route they shared from their Bus tab', _importRoute),
          option(Icons.bookmark_add_outlined, 'Use a ready-made route', "Réduit ⇄ L'Escalier (200), Réduit → Mahebourg (198)", _addPreset),
        ],
      ),
    );
  }

  Future<void> _addRoute() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RouteSheet(),
    );
    if (result == null) return;
    setState(() {
      _routes.add({
        'location_name': result['name'],
        'bus_route': result['number'],
        'schedules': {for (final k in busDayKeys) k: <Map<String, dynamic>>[]},
      });
      _selected = _routes.length - 1;
    });
    BusRepository.setSelectedIndex(_selected);
    await _save();
  }

  Future<void> _editRoute() async {
    final r = _route;
    if (r == null) return;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RouteSheet(name: r['location_name'], number: r['bus_route']),
    );
    if (result == null) return;
    setState(() {
      r['location_name'] = result['name'];
      r['bus_route'] = result['number'];
    });
    await _save();
  }

  Future<void> _deleteRoute() async {
    final r = _route;
    if (r == null) return;
    final ok = await confirmDestructive(context,
        title: 'Delete route?', message: 'Delete "${r['location_name']}" and all its timings?');
    if (!ok) return;
    final removed = r;
    final removedIndex = _selected;
    setState(() {
      _routes.removeAt(_selected);
      _selected = _routes.isEmpty ? 0 : (_selected - 1).clamp(0, _routes.length - 1);
    });
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Route deleted'),
      persist: false, // Flutter keeps action snackbars forever by default
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          setState(() {
            _routes.insert(removedIndex.clamp(0, _routes.length), removed);
            _selected = removedIndex.clamp(0, _routes.length - 1);
          });
          await _save();
        },
      ),
    ));
  }

  void _showRouteMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SheetScaffold(
        title: _route?['location_name'] ?? 'Route',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share this route'),
              subtitle: const Text('Send it to friends who take the same bus'),
              onTap: () {
                Navigator.pop(ctx);
                _shareRoute();
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Share as PDF'),
              subtitle: const Text('A printable timetable'),
              onTap: () async {
                Navigator.pop(ctx);
                final r = _route;
                if (r == null) return;
                final bytes = await PdfExport.busTimetable(r);
                final name = 'Bus_${(r['bus_route'] ?? 'route').toString()}_${_shortName(r['location_name'].toString()).replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}.pdf';
                await Printing.sharePdf(bytes: bytes, filename: name);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename route'),
              onTap: () {
                Navigator.pop(ctx);
                _editRoute();
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: Text('Paste many times (${busDayLabels[_day]})'),
              onTap: () {
                Navigator.pop(ctx);
                _bulkAdd();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_rounded),
              title: Text('Copy ${busDayLabels[_day]} timings to…'),
              onTap: () {
                Navigator.pop(ctx);
                _copyDay();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete route', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteRoute();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyDay() async {
    final r = _route;
    if (r == null) return;
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Copy to'),
        children: [
          for (var i = 0; i < 3; i++)
            if (i != _day) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, i), child: Text(busDayLabels[i])),
        ],
      ),
    );
    if (target == null) return;
    setState(() => r['schedules'][busDayKeys[target]] = _trips);
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied to ${busDayLabels[target]}')));
    }
  }

  // ───────────── Trip actions ─────────────

  /// Typical journey length on this schedule, used to pre-fill arrivals.
  int? get _typicalDuration {
    final d = <int>[];
    for (final t in _trips) {
      final dep = parseMinutes(t['departure']?.toString());
      final arr = parseMinutes(t['arrival']?.toString());
      if (dep != null && arr != null && arr > dep) d.add(arr - dep);
    }
    if (d.isEmpty) return null;
    d.sort();
    return d[d.length ~/ 2];
  }

  List<String> get _busNames {
    final names = <String>{};
    for (final r in _routes) {
      for (final k in busDayKeys) {
        for (final t in (r['schedules']?[k] as List?) ?? const []) {
          final n = (t['bus_name'] ?? '').toString();
          if (n.isNotEmpty) names.add(n);
        }
      }
    }
    return names.toList()..sort();
  }

  Future<void> _editTrip({Map<String, dynamic>? trip, int? index}) async {
    final r = _route;
    if (r == null) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TripSheet(
        trip: trip,
        typicalDuration: _typicalDuration,
        busNames: _busNames,
        dayLabel: busDayLabels[_day],
      ),
    );
    if (result == null) return;

    final trips = _trips;
    final dayKey = busDayKeys[_day];
    if (result['delete'] == true && index != null) {
      final removed = trips.removeAt(index);
      setState(() => r['schedules'][dayKey] = trips);
      await _save();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Removed ${removed['departure']}'),
        persist: false, // Flutter keeps action snackbars forever by default
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            // Restore into the same route/day even if the user switched tabs.
            final current = List<dynamic>.from((r['schedules'][dayKey] as List?) ?? const []);
            setState(() => r['schedules'][dayKey] = [...current, removed]);
            await _save();
          },
        ),
      ));
      return;
    }

    if (index != null) {
      trips[index] = result;
    } else {
      trips.add(result);
    }
    // _save() re-sorts, so the new time lands in its chronological slot.
    setState(() => r['schedules'][busDayKeys[_day]] = trips);
    await _save();
  }

  Future<void> _bulkAdd() async {
    final r = _route;
    if (r == null) return;
    final text = await showControllerDialog<String>(
      context,
      builder: (ctx, controller) => AlertDialog(
        title: Text('Add times to ${busDayLabels[_day]}'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration: const InputDecoration(hintText: '06:14 06:51 07:28\n08:05, 8:42 …'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Add')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;

    final dur = _typicalDuration;
    final added = <Map<String, dynamic>>[];
    for (final token in RegExp(r'\d{1,2}[:.h]\d{2}').allMatches(text).map((m) => m.group(0)!)) {
      final dep = parseMinutes(token);
      if (dep == null) continue;
      added.add({'departure': formatMinutes(dep), 'arrival': dur == null ? '' : formatMinutes(dep + dur)});
    }
    if (added.isEmpty) return;
    setState(() => r['schedules'][busDayKeys[_day]] = [..._trips, ...added]);
    await _save();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${added.length} times')));
  }

  void _scrollToNext() {
    final ctx = _nextKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), alignment: 0.3);
  }

  // ───────────── UI ─────────────

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final trips = _trips;
    final nextIdx = _isTodayTab ? nextTripIndex(trips, nowMin) : 0;
    final firstVisible = !_isTodayTab || _showEarlier || nextIdx <= 0
        ? 0
        : (nextIdx == -1 ? trips.length : nextIdx);
    final hiddenCount = _isTodayTab && !_showEarlier ? (nextIdx == -1 ? trips.length : nextIdx) : 0;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  ScreenHeader(
                    title: 'Bus',
                    eyebrow: '${DateFormat('EEEE').format(now)} · ${DateFormat('HH:mm').format(now)}',
                    actions: [
                      CircleIconButton(icon: Icons.download_rounded, tooltip: 'Import a shared route', onPressed: _importRoute),
                      if (_route != null) CircleIconButton(icon: Icons.more_horiz_rounded, tooltip: 'Route options', onPressed: _showRouteMenu),
                      CircleIconButton(icon: Icons.add_rounded, filled: true, tooltip: 'New route', onPressed: _addRoute),
                    ],
                  ),
                  if (_routes.isEmpty)
                    _buildEmpty(p)
                  else ...[
                    _buildRouteSelector(p),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: PillSegmented<int>(
                        values: const [0, 1, 2],
                        selected: _day,
                        labelOf: (i) => i == busDayIndexFor(now) ? '${busDayLabels[i]} •' : busDayLabels[i],
                        onChanged: (i) => setState(() {
                          _day = i;
                          _showEarlier = false;
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildHero(p, trips, nextIdx, now),
                    ),
                    const SizedBox(height: 22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SectionLabel(
                        '${busDayLabels[_day]} timetable',
                        padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
                        trailing: TextButton.icon(
                          onPressed: () => _editTrip(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add time'),
                        ),
                      ),
                    ),
                    if (trips.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('No buses on this schedule yet', style: TextStyle(color: p.textSecondary))),
                      ),
                    if (hiddenCount > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showEarlier = true),
                          icon: const Icon(Icons.expand_less_rounded),
                          label: Text('Show $hiddenCount earlier bus${hiddenCount == 1 ? '' : 'es'}'),
                        ),
                      ),
                    for (var i = firstVisible; i < trips.length; i++)
                      Padding(
                        key: i == nextIdx ? _nextKey : null,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: _TripRow(
                          trip: trips[i],
                          isNext: _isTodayTab && i == nextIdx,
                          isPast: _isTodayTab && (nextIdx == -1 || i < nextIdx),
                          nowMinutes: nowMin,
                          showCountdown: _isTodayTab,
                          onTap: () => _editTrip(trip: trips[i], index: i),
                        ),
                      ),
                    if (_isTodayTab && nextIdx == -1 && trips.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(child: Text('No more buses today', style: TextStyle(color: p.textSecondary))),
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildRouteSelector(Palette p) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _routes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = _routes[i];
          final sel = i == _selected;
          final number = (r['bus_route'] ?? '').toString();
          return GestureDetector(
            onTap: () => _selectRoute(i),
            onLongPress: () {
              _selectRoute(i);
              _showRouteMenu();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              constraints: const BoxConstraints(maxWidth: 260),
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
              decoration: BoxDecoration(
                color: sel ? p.ink : p.surface,
                borderRadius: BorderRadius.circular(40),
                boxShadow: sel ? null : p.softShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 46,
                    constraints: const BoxConstraints(minWidth: 46),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: sel ? p.accent : p.accentSoft, borderRadius: BorderRadius.circular(30)),
                    child: Text(number.isEmpty ? '—' : number,
                        style: TextStyle(fontWeight: FontWeight.w800, color: sel ? Colors.white : p.accent)),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _shortName(r['location_name']?.toString() ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w600, color: sel ? p.onInk : p.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// "At Réduit (going to L'Escalier)" -> "Réduit → L'Escalier"
  static String _shortName(String name) {
    final m = RegExp(r"^At (.+?) \(going to (.+)\)$").firstMatch(name);
    if (m != null) return '${m.group(1)} → ${m.group(2)}';
    return name;
  }

  Widget _buildHero(Palette p, List<Map<String, dynamic>> trips, int nextIdx, DateTime now) {
    final nowMin = now.hour * 60 + now.minute;
    final route = _route!;
    final number = (route['bus_route'] ?? '').toString();

    String bigValue;
    String bigUnit = '';
    String headline;
    String detail = '';
    String? busName;
    List<String> after = [];

    if (trips.isEmpty) {
      bigValue = '—';
      headline = 'No timings';
      detail = 'Tap "Add time" to add departures';
    } else if (!_isTodayTab) {
      final first = trips.first;
      bigValue = first['departure'];
      headline = 'First bus · ${busDayLabels[_day]}';
      detail = 'Last bus ${trips.last['departure']} · ${trips.length} departures';
      busName = (first['bus_name'] ?? '').toString();
    } else if (nextIdx == -1) {
      bigValue = 'Done';
      headline = 'No more buses today';
      final tomorrowTrips = (route['schedules']?[busDayKeys[busDayIndexFor(now.add(const Duration(days: 1)))]] as List?) ?? const [];
      detail = tomorrowTrips.isEmpty ? '' : 'First bus tomorrow ${tomorrowTrips.first['departure']}';
    } else {
      final t = trips[nextIdx];
      final dep = parseMinutes(t['departure']) ?? nowMin;
      final diff = dep - nowMin;
      if (diff < 60) {
        bigValue = '$diff';
        bigUnit = 'min';
      } else {
        bigValue = formatCountdown(diff);
      }
      headline = diff <= 1 ? 'Leaving now' : 'Next bus';
      final arr = (t['arrival'] ?? '').toString();
      detail = 'Departs ${t['departure']}${arr.isNotEmpty ? ' · arrives $arr' : ''}';
      busName = (t['bus_name'] ?? '').toString();
      after = trips.skip(nextIdx + 1).take(3).map((e) => e['departure'].toString()).toList();
    }

    return GestureDetector(
      onTap: _isTodayTab && nextIdx > 0 ? _scrollToNext : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(32)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 1.3), borderRadius: BorderRadius.circular(40)),
                    child: Text(headline, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                const Spacer(),
                if (number.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_bus_rounded, size: 16, color: p.accent),
                        const SizedBox(width: 6),
                        Text(number, style: TextStyle(color: p.accent, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(bigValue,
                      style: const TextStyle(color: Colors.white, fontSize: 64, height: 1, fontWeight: FontWeight.w300, letterSpacing: -2.5)),
                  if (bigUnit.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(bigUnit, style: const TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(detail, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
            if ((busName ?? '').isNotEmpty || after.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if ((busName ?? '').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(40)),
                      child: Text(busName!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  if (after.isNotEmpty)
                    Text('Then ${after.join(' · ')}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isNext;
  final bool isPast;
  final bool showCountdown;
  final int nowMinutes;
  final VoidCallback onTap;

  const _TripRow({
    required this.trip,
    required this.isNext,
    required this.isPast,
    required this.showCountdown,
    required this.nowMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final dep = (trip['departure'] ?? '').toString();
    final arr = (trip['arrival'] ?? '').toString();
    final bus = (trip['bus_name'] ?? '').toString();
    final depMin = parseMinutes(dep);
    final diff = depMin == null ? null : depMin - nowMinutes;

    return Opacity(
      opacity: isPast ? 0.45 : 1,
      child: SoftCard(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: isNext ? Border.all(color: p.accent, width: 2) : null,
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 86,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dep,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: isNext ? FontWeight.w600 : FontWeight.w300,
                          letterSpacing: -0.8,
                          color: isNext ? p.accent : p.textPrimary,
                          decoration: isPast ? TextDecoration.lineThrough : null)),
                  if (arr.isNotEmpty) Text('→ $arr', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: bus.isEmpty
                  ? const SizedBox()
                  : Align(alignment: Alignment.centerLeft, child: TagPill(bus, color: const Color(0xFFFFA000))),
            ),
            if (showCountdown && !isPast && diff != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: isNext ? p.ink : p.surfaceAlt, borderRadius: BorderRadius.circular(40)),
                child: Text(
                  'in ${formatCountdown(diff)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isNext ? p.onInk : p.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Create / rename a route.
class _RouteSheet extends StatefulWidget {
  final String? name;
  final String? number;
  const _RouteSheet({this.name, this.number});

  @override
  State<_RouteSheet> createState() => _RouteSheetState();
}

class _RouteSheetState extends State<_RouteSheet> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _number = TextEditingController(text: widget.number ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.name == null ? 'New route' : 'Edit route',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.name == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Stop / direction', hintText: "At Réduit (going to L'Escalier)"),
            ),
            const SizedBox(height: 12),
            TextField(controller: _number, decoration: const InputDecoration(labelText: 'Route number', hintText: '200')),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 20),
            InkPillButton(
              label: 'Save',
              expand: true,
              onPressed: () {
                if (_name.text.trim().isEmpty) {
                  setState(() => _error = 'Give the route a name');
                  return;
                }
                Navigator.pop(context, {'name': _name.text.trim(), 'number': _number.text.trim()});
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Add or edit one departure. Arrival is pre-filled from the route's usual
/// journey time; the trip is sorted into place when saved.
class _TripSheet extends StatefulWidget {
  final Map<String, dynamic>? trip;
  final int? typicalDuration;
  final List<String> busNames;
  final String dayLabel;
  const _TripSheet({this.trip, this.typicalDuration, required this.busNames, required this.dayLabel});

  @override
  State<_TripSheet> createState() => _TripSheetState();
}

class _TripSheetState extends State<_TripSheet> {
  int? _dep;
  int? _arr;
  bool _approxArrival = false;
  late final _bus = TextEditingController(text: (widget.trip?['bus_name'] ?? '').toString());

  @override
  void initState() {
    super.initState();
    _dep = parseMinutes(widget.trip?['departure']?.toString());
    final arrRaw = (widget.trip?['arrival'] ?? '').toString();
    _approxArrival = arrRaw.startsWith('~');
    _arr = parseMinutes(arrRaw);
  }

  @override
  void dispose() {
    _bus.dispose();
    super.dispose();
  }

  Future<void> _pick(bool departure) async {
    final current = departure ? _dep : _arr;
    final init = current ?? (departure ? DateTime.now().hour * 60 + DateTime.now().minute : (_dep ?? 480) + (widget.typicalDuration ?? 60));
    final picked = await showScrollTimePicker(context: context, initialTime: TimeOfDay(hour: (init ~/ 60) % 24, minute: init % 60));
    if (picked == null) return;
    setState(() {
      final m = picked.hour * 60 + picked.minute;
      if (departure) {
        final shift = _dep != null && _arr != null ? _arr! - _dep! : widget.typicalDuration;
        _dep = m;
        if (shift != null && shift > 0) _arr = m + shift;
      } else {
        _arr = m;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final editing = widget.trip != null;

    Widget timeBox(String label, int? value, bool departure) => Expanded(
          child: SoftCard(
            color: p.surfaceAlt,
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => _pick(departure),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: p.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value == null ? '--:--' : formatMinutes(value),
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300, letterSpacing: -1, color: p.textPrimary)),
              ],
            ),
          ),
        );

    return SheetScaffold(
      title: editing ? 'Edit ${widget.trip!['departure']}' : 'Add time · ${widget.dayLabel}',
      actions: [
        if (editing)
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            onPressed: () => Navigator.pop(context, {'delete': true}),
          ),
      ],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [timeBox('Departs', _dep, true), const SizedBox(width: 10), timeBox('Arrives', _arr, false)]),
            if (widget.typicalDuration != null && !editing)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text('Arrival auto-filled (+${widget.typicalDuration} min usual journey)',
                    style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ),
            const SizedBox(height: 14),
            TextField(controller: _bus, decoration: const InputDecoration(labelText: 'Bus company (optional)', hintText: 'UBS, Dakar…')),
            if (widget.busNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.busNames
                    .map((n) => ActionChip(label: Text(n), onPressed: () => setState(() => _bus.text = n)))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            InkPillButton(
              label: editing ? 'Save' : 'Add to timetable',
              expand: true,
              onPressed: _dep == null
                  ? null
                  : () {
                      final trip = <String, dynamic>{
                        'departure': formatMinutes(_dep!),
                        'arrival': _arr == null ? '' : '${_approxArrival ? '~' : ''}${formatMinutes(_arr!)}',
                      };
                      if (_bus.text.trim().isNotEmpty) trip['bus_name'] = _bus.text.trim();
                      Navigator.pop(context, trip);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
