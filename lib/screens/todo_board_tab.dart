import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/academic_task.dart';
import '../providers/focus_provider.dart';
import '../providers/timetable_provider.dart';
import '../theme/app_theme.dart';
import '../utils/meeting_links.dart';
import '../utils/time_utils.dart';
import '../widgets/add_edit_task_sheet.dart';
import '../widgets/ui.dart';
import 'home_screen.dart' show HomeNavigation, AppPage;
import 'print_center_screen.dart';

/// Kanban board: To Do → In Progress → Done.
///
/// There is deliberately no swipe-to-delete (it was far too easy to trigger
/// while scrolling). On phones, swiping moves between columns; deleting is
/// in the card menu and always offers Undo.
class TodoBoardTab extends StatefulWidget {
  const TodoBoardTab({super.key});

  @override
  State<TodoBoardTab> createState() => _TodoBoardTabState();
}

enum _Filter { all, exams, assignments, highPriority }

class _TodoBoardTabState extends State<TodoBoardTab> {
  final _pageController = PageController();
  int _column = 0;
  _Filter _filter = _Filter.all;
  String _query = ''; // desktop search box
  String? _hoverColumn;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _matches(AcademicTask t) {
    if (_query.isNotEmpty && !'${t.title} ${t.subject} ${t.type}'.toLowerCase().contains(_query)) return false;
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.exams:
        return t.type == 'Exam' || t.type == 'Test';
      case _Filter.assignments:
        return t.type == 'Assignment' || t.type == 'Project' || t.type == 'Homework';
      case _Filter.highPriority:
        return (t.priority ?? 1) >= 2;
    }
  }

  List<AcademicTask> _columnTasks(TimetableProvider tp, String status) {
    final list = tp.tasksWithStatus(status).where(_matches).toList();
    if (status == TaskStatus.done) {
      list.sort((a, b) => (b.updatedAt ?? b.dueDate).compareTo(a.updatedAt ?? a.dueDate));
    } else {
      list.sort((a, b) {
        final p = (b.priority ?? 1).compareTo(a.priority ?? 1);
        return p != 0 ? p : a.dueDate.compareTo(b.dueDate);
      });
    }
    return list;
  }

  void _goToColumn(int i) {
    setState(() => _column = i);
    if (_pageController.hasClients) {
      _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _move(AcademicTask t, String status) async {
    if (t.effectiveStatus == status) return;
    final tp = context.read<TimetableProvider>();
    final previous = t.effectiveStatus;
    await tp.setTaskStatus(t, status);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Moved to ${TaskStatus.label(status)}'),
        duration: const Duration(seconds: 3),
        persist: false, // Flutter keeps action snackbars forever by default
        action: SnackBarAction(label: 'Undo', onPressed: () => tp.setTaskStatus(t, previous)),
      ));
  }

  Future<void> _clearDone(List<AcademicTask> done) async {
    if (done.isEmpty) return;
    final ok = await confirmDestructive(context,
        title: 'Clear completed?', message: 'Delete ${done.length} completed item${done.length == 1 ? '' : 's'}?', action: 'Clear');
    if (!ok || !mounted) return;
    final tp = context.read<TimetableProvider>();
    final removed = <AcademicTask>[];
    for (final t in done) {
      final r = await tp.deleteTask(t.id);
      if (r != null) removed.add(r);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Cleared ${removed.length} items'),
      persist: false, // Flutter keeps action snackbars forever by default
      action: SnackBarAction(label: 'Undo', onPressed: () async {
        for (final r in removed) {
          await tp.restoreTask(r);
        }
      }),
    ));
  }

  void _showCardMenu(AcademicTask t) {
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SheetScaffold(
        title: t.title,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in TaskStatus.all)
              if (s != t.effectiveStatus)
                ListTile(
                  leading: Icon(_statusIcon(s)),
                  title: Text('Move to ${TaskStatus.label(s)}'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _move(t, s);
                  },
                ),
            if (t.effectiveStatus != TaskStatus.done && t.syncId != null)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Focus on this'),
                subtitle: const Text('Start a focus session linked to this task'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.read<FocusProvider>().setTask(t.syncId, t.title, subject: t.subject);
                  if (t.effectiveStatus == TaskStatus.todo) _move(t, TaskStatus.doing);
                  HomeNavigation.of(context, AppPage.focus);
                },
              ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                showTaskSheet(context, task: t);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirmDestructive(context, title: 'Delete?', message: 'Delete "${t.title}"?');
                if (ok && mounted) await deleteTaskWithUndo(context, t);
              },
            ),
          ],
        ),
      ),
    );
  }

  static IconData _statusIcon(String s) {
    switch (s) {
      case TaskStatus.doing:
        return Icons.timelapse_rounded;
      case TaskStatus.done:
        return Icons.check_circle_rounded;
      default:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tp = context.watch<TimetableProvider>();
    final columns = {for (final s in TaskStatus.all) s: _columnTasks(tp, s)};
    final wide = MediaQuery.of(context).size.width >= 720;
    final openCount = columns[TaskStatus.todo]!.length + columns[TaskStatus.doing]!.length;

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Board',
              badge: CountBadge(openCount),
              eyebrow: 'Your to-dos, deadlines & exams',
              actions: [
                CircleIconButton(
                  icon: Icons.print_rounded,
                  tooltip: 'Print & export',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrintCenterScreen())),
                ),
                CircleIconButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  tooltip: 'Add',
                  onPressed: () => showTaskSheet(context, initialStatus: TaskStatus.all[_column]),
                ),
              ],
            ),
            if (isDesktopPlatform)
              _desktopToolbar(p)
            else
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        showCheckmark: false,
                        label: Text(const {
                          _Filter.all: 'All',
                          _Filter.exams: 'Exams & tests',
                          _Filter.assignments: 'Coursework',
                          _Filter.highPriority: 'High priority',
                        }[f]!),
                        selected: _filter == f,
                        selectedColor: p.ink,
                        backgroundColor: p.surface,
                        labelStyle: TextStyle(color: _filter == f ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: tp.tasks.isEmpty
                  ? EmptyState(
                      icon: Icons.view_kanban_rounded,
                      title: 'Nothing on the board',
                      subtitle: 'Add assignments, exams and to-dos, then drag them across as you go.',
                      action: InkPillButton(label: 'Add first task', icon: Icons.add, onPressed: () => showTaskSheet(context)),
                    )
                  : wide
                      ? _buildWide(p, columns)
                      : _buildNarrow(p, columns),
            ),
          ],
        ),
      ),
    );
  }

  static const _filterLabels = {
    _Filter.all: 'All',
    _Filter.exams: 'Exams & tests',
    _Filter.assignments: 'Coursework',
    _Filter.highPriority: 'High priority',
  };

  /// PC: compact filter tabs plus a search box, in one toolbar row.
  Widget _desktopToolbar(Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Flexible(
            child: PillSegmented<_Filter>(
              values: _Filter.values,
              selected: _filter,
              labelOf: (f) => _filterLabels[f]!,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 260,
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: const TextStyle(fontSize: 13.5),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search tasks',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 34),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trello-style ghost "add" row at the foot of a desktop column.
  Widget _addRow(Palette p, String status) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: HoverTap(
        onTap: () => showTaskSheet(context, initialStatus: status),
        builder: (hover) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: hover ? p.textPrimary.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.add_rounded, size: 16, color: p.textSecondary),
            const SizedBox(width: 6),
            Text('Add task', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.textSecondary)),
          ]),
        ),
      ),
    );
  }

  Widget _buildWide(Palette p, Map<String, List<AcademicTask>> columns) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in TaskStatus.all)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _dropTarget(
                  s,
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: isDesktopPlatform
                        ? BoxDecoration(
                            color: _hoverColumn == s ? p.accentSoft : (p.isDark ? p.surface.withValues(alpha: 0.5) : p.sidebar),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _hoverColumn == s ? p.accent.withValues(alpha: 0.5) : p.border),
                          )
                        : BoxDecoration(
                            color: _hoverColumn == s ? p.accentSoft : p.surfaceAlt.withValues(alpha: p.isDark ? 0.5 : 0.7),
                            borderRadius: BorderRadius.circular(28),
                          ),
                    padding: EdgeInsets.all(isDesktopPlatform ? 8 : 10),
                    child: Column(
                      children: [
                        _columnHeader(p, s, columns[s]!),
                        SizedBox(height: isDesktopPlatform ? 4 : 8),
                        if (isDesktopPlatform) ...[
                          // Cards hug their content; "Add task" follows the last one.
                          Flexible(child: _cardList(columns[s]!, draggable: true, shrinkWrap: true)),
                          if (s != TaskStatus.done) _addRow(p, s),
                        ] else
                          Expanded(child: _cardList(columns[s]!, draggable: true)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNarrow(Palette p, Map<String, List<AcademicTask>> columns) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: _dropTarget(
                    TaskStatus.all[i],
                    GestureDetector(
                      onTap: () => _goToColumn(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _hoverColumn == TaskStatus.all[i]
                              ? p.accent
                              : (_column == i ? p.ink : p.surface),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: _column == i ? null : p.softShadow,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                TaskStatus.label(TaskStatus.all[i]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: _column == i || _hoverColumn == TaskStatus.all[i] ? p.onInk : p.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text('${columns[TaskStatus.all[i]]!.length}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: _column == i ? p.onInk.withValues(alpha: 0.7) : p.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 2),
          child: Row(
            children: [
              Icon(Icons.swipe_rounded, size: 14, color: p.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Swipe to switch columns · hold a card to drag it onto a column',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.textMuted)),
              ),
              if (_column == 2 && columns[TaskStatus.done]!.isNotEmpty)
                TextButton(onPressed: () => _clearDone(columns[TaskStatus.done]!), child: const Text('Clear')),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _column = i),
            children: [
              for (final s in TaskStatus.all)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _cardList(columns[s]!, draggable: true, emptyStatus: s),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _columnHeader(Palette p, String status, List<AcademicTask> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
      child: Row(
        children: [
          Icon(_statusIcon(status), size: 18, color: p.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(TaskStatus.label(status),
                style: TextStyle(fontSize: isDesktopPlatform ? 14 : 17, fontWeight: FontWeight.w600, color: p.textPrimary)),
          ),
          Text('${items.length}', style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w700)),
          if (status == TaskStatus.done && items.isNotEmpty)
            IconButton(
                tooltip: 'Clear completed', icon: const Icon(Icons.clear_all_rounded, size: 20), onPressed: () => _clearDone(items))
          else
            IconButton(
              tooltip: 'Add here',
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: () => showTaskSheet(context, initialStatus: status),
            ),
        ],
      ),
    );
  }

  Widget _dropTarget(String status, Widget child) {
    return DragTarget<AcademicTask>(
      onWillAcceptWithDetails: (d) {
        final ok = d.data.effectiveStatus != status;
        if (ok) setState(() => _hoverColumn = status);
        return ok;
      },
      onLeave: (_) => setState(() => _hoverColumn = null),
      onAcceptWithDetails: (d) {
        setState(() => _hoverColumn = null);
        _move(d.data, status);
      },
      builder: (context, _, __) => child,
    );
  }

  Widget _cardList(List<AcademicTask> items, {required bool draggable, String? emptyStatus, bool shrinkWrap = false}) {
    if (items.isEmpty && shrinkWrap) return const SizedBox(height: 4);
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyStatus == TaskStatus.done ? 'Finished items land here' : 'Nothing here',
            style: TextStyle(color: Palette.of(context).textMuted),
          ),
        ),
      );
    }
    final desktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      padding: EdgeInsets.only(top: 6, bottom: shrinkWrap ? 2 : 24),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final t = items[i];
        final card = _TaskCard(
          task: t,
          onTap: () => showTaskSheet(context, task: t),
          onMenu: () => _showCardMenu(t),
          onAdvance: t.effectiveStatus == TaskStatus.done
              ? null
              : () => _move(t, t.effectiveStatus == TaskStatus.todo ? TaskStatus.doing : TaskStatus.done),
        );
        if (!draggable) return card;
        final feedback = Material(
          color: Colors.transparent,
          child: SizedBox(width: 300, child: Opacity(opacity: 0.9, child: card)),
        );
        return desktop
            ? Draggable<AcademicTask>(data: t, feedback: feedback, childWhenDragging: Opacity(opacity: 0.3, child: card), child: card)
            : LongPressDraggable<AcademicTask>(
                data: t, feedback: feedback, childWhenDragging: Opacity(opacity: 0.3, child: card), child: card);
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final AcademicTask task;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final VoidCallback? onAdvance;

  const _TaskCard({required this.task, required this.onTap, required this.onMenu, this.onAdvance});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = task;
    final done = t.effectiveStatus == TaskStatus.done;
    final color = done ? AppColors.done : (t.colorValue != null ? Color(t.colorValue!) : AppColors.forType(t.type));

    var room = '';
    if (t.description.contains('\n---ROOM---\n')) room = t.description.split('\n---ROOM---\n')[1];

    final today = dateOnly(DateTime.now());
    final daysUntil = dateOnly(t.dueDate).difference(today).inDays;
    String? urgency;
    Color? urgencyColor;
    if (!done) {
      if (daysUntil < 0) {
        urgency = 'Overdue';
        urgencyColor = Colors.red;
      } else if (daysUntil == 0) {
        urgency = 'Today';
        urgencyColor = Colors.redAccent;
      } else if (daysUntil == 1) {
        urgency = 'Tomorrow';
        urgencyColor = Colors.orange;
      } else if (daysUntil <= 3) {
        urgency = '${daysUntil}d left';
        urgencyColor = Colors.amber[800];
      }
    }

    final dateText = t.isSpanning
        ? '${DateFormat('d MMM').format(t.startDate!)} – ${DateFormat('d MMM').format(t.dueDate)}'
        : DateFormat('EEE d MMM, HH:mm').format(t.dueDate);

    if (isDesktopPlatform) {
      return _desktop(context, p, color, done, room, urgency, urgencyColor, dateText);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 14, 6, 12),
        onTap: onTap,
        onLongPress: null,
        child: Opacity(
          opacity: done ? 0.6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(flex: 0, child: TagPill(t.type, color: color)),
                  if ((t.priority ?? 1) >= 2) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.flag_rounded, size: 16, color: Colors.redAccent),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.subject == 'General' ? '' : t.subject,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.textSecondary, fontWeight: FontWeight.w600)),
                  ),
                  if (urgency != null) Flexible(child: TagPill(urgency, color: urgencyColor)),
                  if (done) const Flexible(child: TagPill('Done', color: AppColors.done, icon: Icons.check_rounded)),
                  SizedBox(
                    width: 36,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'More',
                      icon: Icon(Icons.more_vert_rounded, size: 20, color: p.textSecondary),
                      onPressed: onMenu,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  t.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(t.isSpanning ? Icons.date_range_rounded : Icons.schedule_rounded, size: 14, color: p.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(dateText, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  ),
                  if (room.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.location_on_outlined, size: 14, color: p.textSecondary),
                    Flexible(
                      child: Text(room, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    ),
                  ],
                  Builder(builder: (context) {
                    final spent = context.select<FocusProvider, int>((f) => f.minutesForTask(t.syncId));
                    if (spent == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text('⏱ ${spent >= 60 ? '${spent ~/ 60}h ${spent % 60}m' : '${spent}m'}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary)),
                    );
                  }),
                  const Spacer(),
                  if (onAdvance != null)
                    Tooltip(
                      message: t.effectiveStatus == TaskStatus.todo ? 'Start' : 'Mark done',
                      child: Material(
                        color: p.ink,
                        shape: isDesktopPlatform ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) : const CircleBorder(),
                        child: InkWell(
                          customBorder:
                              isDesktopPlatform ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)) : const CircleBorder(),
                          onTap: onAdvance,
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(
                              t.effectiveStatus == TaskStatus.todo ? Icons.play_arrow_rounded : Icons.check_rounded,
                              size: 18,
                              color: p.onInk,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              if (t.meetingLink != null && !done) ...[
                const SizedBox(height: 10),
                JoinMeetingButton(url: t.meetingLink!, dense: true),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// PC card: dense and flat (Linear/Trello-like). Actions appear on hover,
  /// right-click opens the menu.
  Widget _desktop(BuildContext context, Palette p, Color color, bool done, String room, String? urgency, Color? urgencyColor,
      String dateText) {
    final t = task;
    final meta = TextStyle(fontSize: 12, color: p.textSecondary);
    Widget action(IconData icon, String tip, VoidCallback onPressed, {bool ink = false}) => Tooltip(
          message: tip,
          child: Material(
            color: ink ? p.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onPressed,
              child: SizedBox(width: 26, height: 26, child: Icon(icon, size: 16, color: ink ? p.onInk : p.textSecondary)),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onSecondaryTap: onMenu,
        child: HoverTap(
          onTap: onTap,
          builder: (hover) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hover ? p.textMuted.withValues(alpha: 0.6) : p.border),
              boxShadow: hover && !p.isDark
                  ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Opacity(
              opacity: done ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(t.type, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
                    if (t.subject != 'General')
                      Flexible(
                        child: Text('  ·  ${t.subject}', maxLines: 1, overflow: TextOverflow.ellipsis, style: meta.copyWith(fontSize: 11.5)),
                      ),
                    const Spacer(),
                    if ((t.priority ?? 1) >= 2) const Icon(Icons.flag_rounded, size: 14, color: Colors.redAccent),
                    if (urgency != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(urgency, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: urgencyColor)),
                      ),
                    if (done) const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.done),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    t.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 26,
                    child: Row(children: [
                      Icon(t.isSpanning ? Icons.date_range_rounded : Icons.schedule_rounded, size: 13, color: p.textMuted),
                      const SizedBox(width: 4),
                      Flexible(child: Text(dateText, maxLines: 1, overflow: TextOverflow.ellipsis, style: meta)),
                      if (room.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.location_on_outlined, size: 13, color: p.textMuted),
                        Flexible(child: Text(room, maxLines: 1, overflow: TextOverflow.ellipsis, style: meta)),
                      ],
                      Builder(builder: (context) {
                        final spent = context.select<FocusProvider, int>((f) => f.minutesForTask(t.syncId));
                        if (spent == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text('${spent >= 60 ? '${spent ~/ 60}h ${spent % 60}m' : '${spent}m'} focused', style: meta),
                        );
                      }),
                      const Spacer(),
                      IgnorePointer(
                        ignoring: !hover,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: hover ? 1 : 0,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (onAdvance != null)
                              action(
                                t.effectiveStatus == TaskStatus.todo ? Icons.play_arrow_rounded : Icons.check_rounded,
                                t.effectiveStatus == TaskStatus.todo ? 'Start' : 'Mark done',
                                onAdvance!,
                                ink: true,
                              ),
                            const SizedBox(width: 2),
                            action(Icons.more_horiz_rounded, 'More (right-click)', onMenu),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  if (t.meetingLink != null && !done) ...[
                    const SizedBox(height: 8),
                    JoinMeetingButton(url: t.meetingLink!, dense: true),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
