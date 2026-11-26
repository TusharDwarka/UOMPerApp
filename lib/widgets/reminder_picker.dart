import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Common lead times, in minutes: at the time, 1 hour, 1/2/3 days, 1 week.
const reminderPresets = [0, 60, 1440, 2880, 4320, 10080];

/// Multi-select "remind me" chips with a Custom… option (any number of
/// minutes / hours / days / weeks before).
class ReminderPicker extends StatelessWidget {
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;
  const ReminderPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final options = {...reminderPresets, ...selected}.toList()..sort();
    Widget chip(int m) {
      final on = selected.contains(m);
      return FilterChip(
        label: Text(m == 0 ? 'At the time' : '${NotificationService.describeLead(m)} before'),
        selected: on,
        showCheckmark: false,
        selectedColor: p.ink,
        backgroundColor: p.surfaceAlt,
        labelStyle: TextStyle(color: on ? p.onInk : p.textPrimary, fontWeight: FontWeight.w600),
        avatar: on ? Icon(Icons.notifications_active_rounded, size: 16, color: p.onInk) : null,
        onSelected: (v) {
          final next = {...selected};
          v ? next.add(m) : next.remove(m);
          onChanged(next.toList()..sort());
        },
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in options) chip(m),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Custom…'),
          onPressed: () async {
            final m = await showCustomReminderDialog(context);
            if (m != null) onChanged(({...selected, m}.toList()..sort()));
          },
        ),
      ],
    );
  }
}

/// Asks "how long before?" as a number and a unit; returns minutes.
Future<int?> showCustomReminderDialog(BuildContext context) {
  return showDialog<int>(context: context, builder: (_) => const _CustomReminderDialog());
}

class _CustomReminderDialog extends StatefulWidget {
  const _CustomReminderDialog();

  @override
  State<_CustomReminderDialog> createState() => _CustomReminderDialogState();
}

class _CustomReminderDialogState extends State<_CustomReminderDialog> {
  final _amount = TextEditingController(text: '2');
  int _unit = 1440;

  static const _units = {1: 'minutes', 60: 'hours', 1440: 'days', 10080: 'weeks'};

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = int.tryParse(_amount.text.trim());
    final valid = n != null && n > 0 && n * _unit <= 60 * 1440;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text('Remind me before'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            SizedBox(
              width: 80,
              child: TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _unit,
                borderRadius: BorderRadius.circular(isDesktopPlatform ? 12 : 18),
                items: [for (final e in _units.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _unit = v ?? _unit),
              ),
            ),
          ]),
          if (!valid)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Pick something up to 60 days before', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: valid ? () => Navigator.pop(context, n * _unit) : null, child: const Text('Add')),
      ],
    );
  }
}
