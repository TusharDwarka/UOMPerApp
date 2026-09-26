import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/focus_provider.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import '../widgets/weekly_chart.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  String _hm(int minutes) => minutes >= 60 ? '${minutes ~/ 60}h ${minutes % 60}min' : '${minutes}min';

  Future<void> _editDurations(BuildContext context, FocusProvider focus) async {
    var f = focus.focusMinutes, b = focus.breakMinutes, g = focus.dailyGoalMinutes;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SheetScaffold(
          title: 'Timer settings',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _slider('Focus length', f, 10, 90, 5, (v) => setSheet(() => f = v)),
              _slider('Break length', b, 3, 30, 1, (v) => setSheet(() => b = v)),
              _slider('Daily goal', g, 30, 480, 15, (v) => setSheet(() => g = v)),
              const SizedBox(height: 12),
              InkPillButton(
                label: 'Save',
                expand: true,
                onPressed: () {
                  focus.setDurations(focus: f, rest: b, goal: g);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider(String label, int value, int min, int max, int step, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: (max - min) ~/ step,
            label: '$value min',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(width: 60, child: Text('$value min', textAlign: TextAlign.right)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final focus = context.watch<FocusProvider>();
    final modules = context.select<TimetableProvider, List<String>>((t) => t.userSessions.map((s) => s.subject).toSet().toList()..sort());
    final todayIdx = DateTime.now().weekday - 1;
    final goalProgress = (focus.todayMinutes / focus.dailyGoalMinutes).clamp(0.0, 1.0);
    final activeDays = focus.weekMinutes().take(todayIdx + 1).where((m) => m > 0).length;
    final avg = activeDays == 0 ? 0 : focus.thisWeekTotal ~/ activeDays;
    final wow = focus.weekOverWeekPercent;

    final phaseLabel = switch (focus.phase) {
      FocusPhase.idle => 'Ready',
      FocusPhase.focus => focus.isPaused ? 'Paused' : 'Focusing',
      FocusPhase.rest => 'Break',
    };

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            ScreenHeader(
              title: 'Focus',
              eyebrow: 'Deep-work timer',
              actions: [CircleIconButton(icon: Icons.tune_rounded, tooltip: 'Timer settings', onPressed: () => _editDurations(context, focus))],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Time Average 4h 32min (6)"
                  Text('Time average', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w300, letterSpacing: -1.2, color: p.textSecondary)),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: _hm(avg)),
                      TextSpan(text: ' ($activeDays)', style: const TextStyle(fontSize: 16, letterSpacing: 0)),
                    ]),
                    style: TextStyle(fontSize: 40, height: 1.1, fontWeight: FontWeight.w400, letterSpacing: -1.6, color: p.textPrimary),
                  ),
                  const SizedBox(height: 18),

                  // ── Timer card ──
                  SoftCard(
                    radius: 36,
                    color: focus.phase == FocusPhase.idle ? null : p.accent,
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                border: Border.all(color: focus.phase == FocusPhase.idle ? p.textPrimary : Colors.white, width: 1.3),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Text(phaseLabel,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: focus.phase == FocusPhase.idle ? p.textPrimary : Colors.white)),
                            ),
                            const Spacer(),
                            if (focus.label.isNotEmpty && focus.phase != FocusPhase.idle)
                              Flexible(
                                child: Text(focus.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 210,
                          height: 210,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: focus.phase == FocusPhase.idle ? 0 : focus.progress,
                                strokeWidth: 12,
                                strokeCap: StrokeCap.round,
                                backgroundColor: focus.phase == FocusPhase.idle ? p.surfaceAlt : Colors.white24,
                                color: focus.phase == FocusPhase.idle ? p.accent : Colors.white,
                              ),
                              Center(
                                child: Text(
                                  _fmt(focus.phase == FocusPhase.idle ? Duration(minutes: focus.focusMinutes) : focus.remaining),
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: -2,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: focus.phase == FocusPhase.idle ? p.textPrimary : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (focus.phase == FocusPhase.idle) ...[
                          if (modules.isNotEmpty)
                            SizedBox(
                              height: 40,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final m in modules)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(m, overflow: TextOverflow.ellipsis),
                                        selected: focus.label == m,
                                        showCheckmark: false,
                                        selectedColor: p.ink,
                                        labelStyle: TextStyle(color: focus.label == m ? p.onInk : p.textPrimary),
                                        onSelected: (sel) => focus.setLabel(sel ? m : ''),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 14),
                          InkPillButton(
                            label: 'Start ${focus.focusMinutes} min focus',
                            icon: Icons.play_arrow_rounded,
                            expand: true,
                            onPressed: () => focus.start(),
                          ),
                        ] else
                          Row(
                            children: [
                              Expanded(
                                child: _WhitePill(
                                  label: focus.isPaused ? 'Resume' : 'Pause',
                                  icon: focus.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                  onTap: focus.isPaused ? focus.resume : focus.pause,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: _WhitePill(label: 'Stop', icon: Icons.stop_rounded, onTap: focus.stop, outlined: true)),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Today + streak ──
                  Row(
                    children: [
                      Expanded(
                        child: SoftCard(
                          radius: 28,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Today', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(_hm(focus.todayMinutes),
                                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w300, letterSpacing: -1, color: p.textPrimary)),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(value: goalProgress, minHeight: 7, backgroundColor: p.surfaceAlt, color: p.accent),
                              ),
                              const SizedBox(height: 6),
                              Text('Goal ${_hm(focus.dailyGoalMinutes)}', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SoftCard(
                          radius: 28,
                          color: p.ink,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Streak', style: TextStyle(color: p.onInk.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text('${focus.streak} 🔥',
                                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w300, color: p.onInk)),
                              const SizedBox(height: 10),
                              Text('days with 25+ min', style: TextStyle(fontSize: 12, color: p.onInk.withValues(alpha: 0.7))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  WeeklyBarsChart(values: focus.weekMinutes(), todayIndex: todayIdx),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.north_east_rounded, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('Weekly productivity', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                      ),
                      const SizedBox(width: 8),
                      if (wow != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(8)),
                          child: Text('${wow >= 0 ? '+' : ''}$wow%', style: TextStyle(color: p.onInk, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Last week ${_hm(focus.lastWeekTotal)}', textAlign: TextAlign.right, maxLines: 1,
                            overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Your weekly focus also counts on your groups\' leaderboards.',
                      style: TextStyle(fontSize: 12, color: p.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhitePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;
  const _WhitePill({required this.label, required this.icon, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? Colors.white : AppColors.accent;
    return Material(
      color: outlined ? Colors.transparent : Colors.white,
      shape: StadiumBorder(side: outlined ? const BorderSide(color: Colors.white, width: 1.4) : BorderSide.none),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
