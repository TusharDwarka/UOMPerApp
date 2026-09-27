import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/class_session.dart';
import '../providers/timetable_provider.dart';
import '../services/ai_service.dart';
import '../widgets/add_edit_class_sheet.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1 — Course name
  final TextEditingController _courseNameController = TextEditingController();

  // Step 2 — Timetable upload
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String _selectedMimeType = 'image/png';

  // Step 3 — AI processing
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Step 4 — Parsed sessions
  List<Map<String, dynamic>> _parsedSessions = [];
  List<bool> _sessionSelected = [];

  // Semester config
  DateTime _semesterStart = DateTime.now();
  DateTime? _semesterEnd;
  final TextEditingController _semesterStartController = TextEditingController();
  final TextEditingController _semesterEndController = TextEditingController();

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _semesterStartController.text = '${_semesterStart.year}-${_semesterStart.month.toString().padLeft(2, '0')}-${_semesterStart.day.toString().padLeft(2, '0')}';
    _semesterEnd = _semesterStart.add(const Duration(days: 105)); // 15 weeks
    _semesterEndController.text = '${_semesterEnd!.year}-${_semesterEnd!.month.toString().padLeft(2, '0')}-${_semesterEnd!.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _courseNameController.dispose();
    _semesterStartController.dispose();
    _semesterEndController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedFileBytes = bytes;
          _selectedFileName = picked.name;
          final ext = picked.name.toLowerCase();
          if (ext.endsWith('.jpg') || ext.endsWith('.jpeg')) {
            _selectedMimeType = 'image/jpeg';
          } else if (ext.endsWith('.webp')) {
            _selectedMimeType = 'image/webp';
          } else {
            _selectedMimeType = 'image/png';
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick image: $e');
    }
  }

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedFileBytes = result.files.single.bytes;
          _selectedFileName = result.files.single.name;
          _selectedMimeType = 'application/pdf';
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick PDF: $e');
    }
  }

  void _skipToManualBuilder() {
    final courseName = _courseNameController.text.trim();
    if (courseName.isEmpty) {
      setState(() => _errorMessage = 'Please go back and enter your course name.');
      return;
    }
    setState(() {
      _parsedSessions = [];
      _sessionSelected = [];
      _errorMessage = null;
    });
    _goToStep(3); // Go straight to confirm/builder step
  }

  Future<void> _processWithAi() async {
    final courseName = _courseNameController.text.trim();
    if (courseName.isEmpty) {
      setState(() => _errorMessage = 'Please go back and enter your course name.');
      return;
    }

    if (_selectedFileBytes == null) {
      setState(() => _errorMessage = 'Please select a timetable file first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    _goToStep(2); // Processing step

    try {
      final aiService = AiService();
      final results = await aiService.parseTimetableFromFile(
        fileBytes: _selectedFileBytes!,
        courseName: courseName,
        mimeType: _selectedMimeType,
      );

      if (results.isEmpty) {
        throw Exception("We couldn't detect a valid timetable in this file. Please try another one.");
      }

      setState(() {
        _parsedSessions = results;
        _sessionSelected = List.generate(results.length, (_) => true);
        _isProcessing = false;
      });
      _goToStep(3); // Confirm step
    } catch (e) {
      String msg = "Failed to process timetable. Please try again.";
      final eStr = e.toString().toLowerCase();
      
      if (e is UnsupportedError) {
        msg = e.message ?? "Timetable scanning is available on the phone app.";
      } else if (eStr.contains("403") || eStr.contains("permission") || eStr.contains("has not been used") || eStr.contains("disabled")) {
        msg = "AI scanning isn't switched on for this app yet (Firebase → AI Logic). You can add classes manually meanwhile.";
      } else if (eStr.contains("quota") || eStr.contains("429") || eStr.contains("overloaded")) {
        msg = "The AI servers are currently busy or overloaded. Please try again in a minute.";
      } else if (eStr.contains("detect a valid timetable")) {
        msg = "We couldn't detect a valid timetable in this file. Please try a clearer picture.";
      } else if (eStr.contains("network") || eStr.contains("socket") || eStr.contains("connection")) {
        msg = "Network error. Please check your internet connection.";
      }

      setState(() {
        _isProcessing = false;
        _errorMessage = msg;
      });
      _goToStep(1); // Back to upload step
    }
  }

  Future<void> _saveAndFinish() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    debugPrint("DEBUG: _saveAndFinish started");
    try {
      final provider = Provider.of<TimetableProvider>(context, listen: false);
      final courseName = _courseNameController.text.trim();
      debugPrint("DEBUG: courseName = $courseName");

      // Build ClassSession list from selected parsed sessions
      final sessions = <ClassSession>[];
      for (int i = 0; i < _parsedSessions.length; i++) {
        if (!_sessionSelected[i]) continue;

        final s = _parsedSessions[i];
        List<int>? weeksList;
        if (s['weeks'] != null && s['weeks'] is List && (s['weeks'] as List).isNotEmpty) {
          weeksList = (s['weeks'] as List).map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0).toList();
        }

        sessions.add(ClassSession(
          subject: s['moduleName'] ?? '',
          startTime: s['startTime'] ?? '',
          endTime: s['endTime'] ?? '',
          day: s['day'] ?? '',
          room: s['location'] ?? 'TBD',
          moduleCode: s['moduleCode'] ?? '',
          isUser: true,
          weeks: weeksList,
          specificDate: s['specificDate'] != null ? DateTime.tryParse(s['specificDate']) : null,
        ));
      }

      debugPrint("DEBUG: sessions built. Count = ${sessions.length}");

      // Save course name and semester dates
      await provider.setCourseName(courseName);
      debugPrint("DEBUG: setCourseName completed");
      await provider.setSemesterDates(_semesterStart, _semesterEnd);
      debugPrint("DEBUG: setSemesterDates completed");
      await provider.importAiSessions(sessions);
      debugPrint("DEBUG: importAiSessions completed");
      // Setup is marked complete in _finishSetup: flipping it here made the
      // app jump to Home before the notification step could be shown.

      // Instead of going to home screen, go to notifications permission step
      if (mounted) {
        _goToStep(4);
      }
    } catch (e, stackTrace) {
      debugPrint("DEBUG: _saveAndFinish ERROR: $e\n$stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(p),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1CourseName(p),
                  _buildStep2Upload(p),
                  _buildStep3Processing(p),
                  _buildStep4Confirm(p),
                  _buildStep5Permissions(p),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Palette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Row(
        children: List.generate(5, (index) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: index <= _currentStep ? p.ink : p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Shared pieces (same language as the sign-in screen) ──

  Widget _badge(Palette p, IconData icon) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
        child: Icon(icon, color: p.onInk, size: 30),
      );

  Widget _heading(Palette p, String title, String subtitle) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 40, height: 1.05, fontWeight: FontWeight.w300, letterSpacing: -1.6, color: p.textPrimary)),
          const SizedBox(height: 10),
          Text(subtitle, style: TextStyle(fontSize: 15, height: 1.4, color: p.textSecondary)),
        ],
      );

  Widget _primaryButton(String label, VoidCallback onTap, {IconData icon = Icons.arrow_forward_rounded, bool isLoading = false}) {
    final p = Palette.of(context);
    return SizedBox(
      width: double.infinity,
      child: isLoading
          ? Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: p.accent)))
          : InkPillButton(label: label, icon: icon, expand: true, onPressed: onTap),
    );
  }

  Widget _dateTile(Palette p, {required String label, required String value, required IconData icon, required VoidCallback onTap, Widget? trailing}) {
    return SoftCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.textSecondary)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: p.textPrimary)),
              ],
            ),
          ),
          trailing ?? Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.expand_more_rounded, color: p.textMuted)),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red[400]),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: Colors.red[400], fontSize: 13))),
        ],
      ),
    );
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickSemesterStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _semesterStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      _semesterStart = picked;
      _semesterStartController.text = _ymd(picked);
      // Auto-update end date
      _semesterEnd = picked.add(const Duration(days: 105));
      _semesterEndController.text = _ymd(_semesterEnd!);
    });
  }

  Future<void> _pickSemesterEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _semesterEnd ?? _semesterStart.add(const Duration(days: 90)),
      firstDate: _semesterStart,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() {
      _semesterEnd = picked;
      _semesterEndController.text = _ymd(picked);
    });
  }

  // ==========================================
  // STEP 1: Course Name
  // ==========================================
  Widget _buildStep1CourseName(Palette p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(p, Icons.school_rounded),
          const SizedBox(height: 26),
          _heading(p, 'What are\nyou studying?', 'Your course name helps the AI read your timetable.'),
          const SizedBox(height: 28),
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: TextField(
              controller: _courseNameController,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. BSc Data Science', prefixIcon: Icon(Icons.edit_rounded, size: 20)),
            ),
          ),
          const SizedBox(height: 12),
          const SectionLabel('Semester'),
          _dateTile(p,
              label: 'Starts', value: _semesterStartController.text, icon: Icons.calendar_today_rounded, onTap: _pickSemesterStart),
          const SizedBox(height: 10),
          _dateTile(
            p,
            label: 'Ends (optional)',
            value: _semesterEndController.text.isEmpty ? 'No end date' : _semesterEndController.text,
            icon: Icons.event_rounded,
            onTap: _pickSemesterEnd,
            trailing: _semesterEnd == null
                ? null
                : IconButton(
                    tooltip: 'Clear end date',
                    icon: Icon(Icons.close_rounded, size: 20, color: p.textSecondary),
                    onPressed: () => setState(() {
                      _semesterEnd = null;
                      _semesterEndController.clear();
                    }),
                  ),
          ),
          const SizedBox(height: 32),
          _primaryButton('Continue', () {
            if (_courseNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please enter your course name")),
              );
              return;
            }
            _goToStep(1);
          }),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: Upload Timetable
  // ==========================================
  Widget _buildStep2Upload(Palette p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => _goToStep(0)),
          const SizedBox(height: 22),
          _heading(p, 'Add your\ntimetable', 'Snap or upload it and the AI pulls out every class. Or build it by hand.'),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _errorBox(_errorMessage!),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildUploadCard(p,
                    icon: Icons.camera_alt_rounded, label: 'Camera', subtitle: 'Take a photo', onTap: () => _pickImage(ImageSource.camera)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUploadCard(p, icon: Icons.picture_as_pdf_rounded, label: 'PDF', subtitle: 'Upload document', onTap: _pickPdf),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildUploadCard(p,
                    icon: Icons.photo_library_rounded, label: 'Gallery', subtitle: 'Pick an image', onTap: () => _pickImage(ImageSource.gallery)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUploadCard(p,
                    icon: Icons.edit_calendar_rounded, label: 'Manual', subtitle: 'Build it yourself', onTap: _skipToManualBuilder),
              ),
            ],
          ),
          if (_selectedFileBytes != null) ...[
            const SizedBox(height: 16),
            SoftCard(
              radius: 24,
              padding: const EdgeInsets.all(16),
              border: Border.all(color: const Color(0xFF00C853), width: 1.5),
              child: Row(
                children: [
                  Icon(_selectedMimeType == 'application/pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      color: const Color(0xFF00C853), size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedFileName ?? 'File selected', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
                        Text('Ready for AI analysis', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF00C853)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          _primaryButton('Analyze with AI', () {
            if (_selectedFileBytes == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select a timetable file first, or choose Manual")),
              );
              return;
            }
            _processWithAi();
          }, icon: Icons.auto_awesome_rounded),
        ],
      ),
    );
  }

  Widget _buildUploadCard(Palette p, {required IconData icon, required String label, required String subtitle, required VoidCallback onTap}) {
    return SoftCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, color: p.accent, size: 22),
          ),
          const SizedBox(height: 14),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 3: Processing / Loading
  // ==========================================
  Widget _buildStep3Processing(Palette p) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Transform.scale(scale: 1.0 + (_pulseController.value * 0.12), child: child),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: p.ink, shape: BoxShape.circle),
                child: Icon(Icons.auto_awesome_rounded, size: 40, color: p.onInk),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'Reading your\ntimetable…',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, height: 1.1, fontWeight: FontWeight.w300, letterSpacing: -1.2, color: p.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'The AI is pulling out every class, time and room.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4, color: p.textSecondary),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(minHeight: 4, backgroundColor: p.surfaceAlt, color: p.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 4: Confirm Parsed Sessions
  // ==========================================
  Widget _buildStep4Confirm(Palette p) {
    final selectedCount = _sessionSelected.where((s) => s).length;
    final manual = _parsedSessions.isEmpty;

    // Group sessions by day for display
    final Map<String, List<int>> grouped = {};
    for (int i = 0; i < _parsedSessions.length; i++) {
      final day = _parsedSessions[i]['day'] ?? 'Unknown';
      grouped.putIfAbsent(day, () => []);
      grouped[day]!.add(i);
    }

    final dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final sortedDays = grouped.keys.toList()..sort((a, b) {
      final ia = dayOrder.indexOf(a);
      final ib = dayOrder.indexOf(b);
      return (ia == -1 ? 99 : ia).compareTo(ib == -1 ? 99 : ib);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Row(
            children: [
              CircleIconButton(icon: Icons.arrow_back_rounded, tooltip: 'Back', onPressed: () => _goToStep(1)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(manual ? 'Build classes' : 'Confirm classes', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w300, letterSpacing: -0.8, color: p.textPrimary)),
                    Text(manual ? 'Add your classes by hand' : '$selectedCount of ${_parsedSessions.length} selected',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TagPill(manual ? 'Manual' : 'AI parsed',
                  icon: manual ? Icons.edit_rounded : Icons.auto_awesome_rounded,
                  color: manual ? p.textSecondary : const Color(0xFF00C853)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            children: [
              for (final day in sortedDays) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 8, left: 4),
                  child: Text(day.toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: p.textSecondary, letterSpacing: 1.4)),
                ),
                for (final idx in grouped[day]!) _buildSessionCard(idx, p),
              ],
              if (manual)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      "No classes added yet.\nTap 'Add a class' to start building.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textMuted),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _showAddEditClassSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add a class'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
          child: _primaryButton(selectedCount == 1 ? 'Save 1 class' : 'Save $selectedCount classes', _saveAndFinish,
              icon: Icons.check_rounded, isLoading: _isSaving),
        ),
      ],
    );
  }

  Widget _buildSessionCard(int index, Palette p) {
    final s = _parsedSessions[index];
    final isSelected = _sessionSelected[index];
    const colors = AppColors.eventPalette;
    final accent = colors[(s['moduleName'] ?? '').hashCode.abs() % colors.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: isSelected ? 1 : 0.5,
        child: SoftCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          onTap: () => setState(() => _sessionSelected[index] = !_sessionSelected[index]),
          child: Row(
            children: [
              Container(width: 4, height: 40, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['moduleName'] ?? 'Unknown Module',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: p.textPrimary,
                        decoration: isSelected ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${s['startTime']} – ${s['endTime']}  •  ${s['location'] ?? 'TBD'}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: p.textSecondary),
                    ),
                    if (s['moduleCode'] != null && s['moduleCode'].toString().isNotEmpty)
                      Text(s['moduleCode'].toString(), style: TextStyle(fontSize: 11, color: p.textMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                icon: Icon(Icons.edit_rounded, size: 20, color: p.textSecondary),
                onPressed: () => _showAddEditClassSheet(index: index),
              ),
              Checkbox(
                value: isSelected,
                onChanged: (v) => setState(() => _sessionSelected[index] = v ?? true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 5: Notifications ---
  Widget _buildStep5Permissions(Palette p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(p, Icons.notifications_active_rounded),
          const SizedBox(height: 26),
          _heading(p, 'Never miss\na class', "We'll nudge you 15 minutes before each class starts."),
          const SizedBox(height: 40),
          _primaryButton('Turn on reminders', () => _finishSetup(true), icon: Icons.notifications_rounded),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _finishSetup(false),
              child: Text('Not now', style: TextStyle(color: p.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finishSetup(bool enableNotifications) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (enableNotifications) {
      final granted = await NotificationService().requestPermissions();
      await prefs.setBool('class_reminders_enabled', granted);
    } else {
      await prefs.setBool('class_reminders_enabled', false);
    }

    if (!mounted) return;
    // SignedInGate (main.dart) swaps Onboarding for Home when this flips.
    // Navigating here with pushAndRemoveUntil would also remove the auth
    // listener, breaking sign-out and live sync.
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    await provider.setSetupCompleted(true);
    await provider.rescheduleReminders();
  }

  // --- Add / Edit Class Bottom Sheet ---
  Future<void> _showAddEditClassSheet({int? index}) async {
    final initialData = index != null ? _parsedSessions[index] : null;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditClassSheet(initialData: initialData),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          _parsedSessions[index] = result;
          _sessionSelected[index] = true; // Auto-select if edited
        } else {
          _parsedSessions.add(result);
          _sessionSelected.add(true);
        }
      });
    }
  }
}
