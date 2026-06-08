import 'package:flutter/material.dart';

/// A beautiful iOS-style scroll-wheel time picker with presets.
/// Returns a [TimeOfDay] when the user taps "Done".
Future<TimeOfDay?> showScrollTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ScrollTimePickerSheet(initialTime: initialTime),
  );
}

class _ScrollTimePickerSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  const _ScrollTimePickerSheet({required this.initialTime});

  @override
  State<_ScrollTimePickerSheet> createState() => _ScrollTimePickerSheetState();
}

class _ScrollTimePickerSheetState extends State<_ScrollTimePickerSheet> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _periodController;

  final List<int> _hours = List.generate(12, (i) => i + 1); // 1..12
  final List<int> _minutes = List.generate(60, (i) => i);   // 0..59
  final List<String> _periods = ['am', 'pm'];

  late int _selectedHourIndex;
  late int _selectedMinuteIndex;
  late int _selectedPeriodIndex;

  @override
  void initState() {
    super.initState();
    // Convert 24h TimeOfDay to 12h for our wheels
    int h = widget.initialTime.hourOfPeriod;
    if (h == 0) h = 12;
    _selectedHourIndex = h - 1; // index in _hours (0-based)
    _selectedMinuteIndex = widget.initialTime.minute;
    _selectedPeriodIndex = widget.initialTime.period == DayPeriod.am ? 0 : 1;

    _hourController = FixedExtentScrollController(initialItem: _selectedHourIndex);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinuteIndex);
    _periodController = FixedExtentScrollController(initialItem: _selectedPeriodIndex);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  TimeOfDay _buildTimeOfDay() {
    int hour12 = _hours[_selectedHourIndex]; // 1-12
    bool isPm = _selectedPeriodIndex == 1;
    int hour24;
    if (hour12 == 12) {
      hour24 = isPm ? 12 : 0;
    } else {
      hour24 = isPm ? hour12 + 12 : hour12;
    }
    return TimeOfDay(hour: hour24, minute: _minutes[_selectedMinuteIndex]);
  }

  void _applyPreset(int hour24, int minute) {
    int h12 = hour24 % 12;
    if (h12 == 0) h12 = 12;
    int periodIdx = hour24 >= 12 ? 1 : 0;

    setState(() {
      _selectedHourIndex = h12 - 1;
      _selectedMinuteIndex = minute;
      _selectedPeriodIndex = periodIdx;
    });

    _hourController.animateToItem(_selectedHourIndex, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    _minuteController.animateToItem(_selectedMinuteIndex, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    _periodController.animateToItem(_selectedPeriodIndex, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final dimColor = isDark ? Colors.white38 : Colors.black26;
    final accentBlue = const Color(0xFF2962FF);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),

            // Title
            Text("Time", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 16),

            // Scroll Wheels
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  // Selection highlight band
                  Center(
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hour wheel
                      SizedBox(
                        width: 70,
                        child: ListWheelScrollView.useDelegate(
                          controller: _hourController,
                          itemExtent: 44,
                          physics: const FixedExtentScrollPhysics(),
                          perspective: 0.003,
                          diameterRatio: 1.5,
                          onSelectedItemChanged: (i) => setState(() => _selectedHourIndex = i),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: _hours.length,
                            builder: (context, index) {
                              final isSelected = index == _selectedHourIndex;
                              return Center(
                                child: Text(
                                  '${_hours[index]}',
                                  style: TextStyle(
                                    fontSize: isSelected ? 28 : 18,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                    color: isSelected ? textColor : dimColor,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Colon separator
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(":", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                      ),

                      // Minute wheel
                      SizedBox(
                        width: 70,
                        child: ListWheelScrollView.useDelegate(
                          controller: _minuteController,
                          itemExtent: 44,
                          physics: const FixedExtentScrollPhysics(),
                          perspective: 0.003,
                          diameterRatio: 1.5,
                          onSelectedItemChanged: (i) => setState(() => _selectedMinuteIndex = i),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: _minutes.length,
                            builder: (context, index) {
                              final isSelected = index == _selectedMinuteIndex;
                              return Center(
                                child: Text(
                                  _minutes[index].toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: isSelected ? 28 : 18,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                    color: isSelected ? textColor : dimColor,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // AM/PM wheel
                      SizedBox(
                        width: 60,
                        child: ListWheelScrollView.useDelegate(
                          controller: _periodController,
                          itemExtent: 44,
                          physics: const FixedExtentScrollPhysics(),
                          perspective: 0.003,
                          diameterRatio: 1.5,
                          onSelectedItemChanged: (i) => setState(() => _selectedPeriodIndex = i),
                          childDelegate: ListWheelChildBuilderDelegate(
                            childCount: _periods.length,
                            builder: (context, index) {
                              final isSelected = index == _selectedPeriodIndex;
                              return Center(
                                child: Text(
                                  _periods[index],
                                  style: TextStyle(
                                    fontSize: isSelected ? 22 : 16,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                    color: isSelected ? textColor : dimColor,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Presets
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Presets", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: dimColor)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _presetChip("8 am", 8, 0, isDark, accentBlue),
                      _presetChip("9 am", 9, 0, isDark, accentBlue),
                      _presetChip("10 am", 10, 0, isDark, accentBlue),
                      _presetChip("12 pm", 12, 0, isDark, accentBlue),
                      _presetChip("2 pm", 14, 0, isDark, accentBlue),
                      _presetChip("4 pm", 16, 0, isDark, accentBlue),
                      _presetChip("6 pm", 18, 0, isDark, accentBlue),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Done button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _buildTimeOfDay()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("Done", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _presetChip(String label, int hour24, int minute, bool isDark, Color accentBlue) {
    // Check if currently selected matches this preset
    final currentTime = _buildTimeOfDay();
    final isActive = currentTime.hour == hour24 && currentTime.minute == minute;

    return GestureDetector(
      onTap: () => _applyPreset(hour24, minute),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accentBlue.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? accentBlue : (isDark ? Colors.white12 : Colors.grey[300]!)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? accentBlue : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
