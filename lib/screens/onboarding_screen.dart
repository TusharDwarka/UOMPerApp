import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/class_session.dart';
import '../providers/timetable_provider.dart';
import '../services/ai_service.dart';
import 'home_screen.dart';

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
  String? _errorMessage;

  // Step 4 — Parsed sessions
  List<Map<String, dynamic>> _parsedSessions = [];
  List<bool> _sessionSelected = [];

  // Semester config
  DateTime _semesterStart = DateTime.now();
  final TextEditingController _semesterStartController = TextEditingController();

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _semesterStartController.text = '${_semesterStart.year}-${_semesterStart.month.toString().padLeft(2, '0')}-${_semesterStart.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _courseNameController.dispose();
    _semesterStartController.dispose();
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

      setState(() {
        _parsedSessions = results;
        _sessionSelected = List.generate(results.length, (_) => true);
        _isProcessing = false;
      });
      _goToStep(3); // Confirm step
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
      _goToStep(1); // Back to upload step
    }
  }

  Future<void> _saveAndFinish() async {
    final provider = Provider.of<TimetableProvider>(context, listen: false);
    final courseName = _courseNameController.text.trim();

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
      ));
    }

    // Save course name and semester start
    await provider.setCourseName(courseName);
    await provider.setSemesterStart(_semesterStart);
    await provider.importAiSessions(sessions);
    await provider.setSetupCompleted(true);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressBar(isDark),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1CourseName(isDark),
                  _buildStep2Upload(isDark),
                  _buildStep3Processing(isDark),
                  _buildStep4Confirm(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isActive
                    ? (isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF))
                    : (isDark ? Colors.white10 : Colors.grey[300]),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==========================================
  // STEP 1: Course Name
  // ==========================================
  Widget _buildStep1CourseName(bool isDark) {
    final accentColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.school_rounded, size: 40, color: accentColor),
          ),
          const SizedBox(height: 30),
          Text(
            "What are you\nstudying?",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1D1E),
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Enter your course or programme name. This helps the AI understand your timetable better.",
            style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _courseNameController,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "e.g. BSc Data Science, Agriculture...",
              hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontWeight: FontWeight.normal),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Icon(Icons.edit_rounded, color: accentColor),
              ),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),

          // Semester Start Date
          Text("Semester Start Date", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _semesterStart,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() {
                  _semesterStart = picked;
                  _semesterStartController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, color: accentColor, size: 20),
                  const SizedBox(width: 16),
                  Text(
                    _semesterStartController.text,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: isDark ? Colors.grey[500] : Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 50),
          _buildContinueButton("Continue", () {
            if (_courseNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please enter your course name")),
              );
              return;
            }
            _goToStep(1);
          }, isDark),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: Upload Timetable
  // ==========================================
  Widget _buildStep2Upload(bool isDark) {
    final accentColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              GestureDetector(
                onTap: () => _goToStep(0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back, size: 20, color: isDark ? Colors.white : Colors.black),
                ),
              ),
              const SizedBox(width: 16),
              Text("Upload Timetable", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Upload your timetable (Image or PDF). The AI will extract all your classes automatically. Or, you can build it manually.",
            style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.5),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 30),

          // Upload options
          Row(
            children: [
              Expanded(
                child: _buildUploadCard(
                  icon: Icons.camera_alt_rounded,
                  label: "Camera",
                  subtitle: "Take a photo",
                  onTap: () => _pickImage(ImageSource.camera),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildUploadCard(
                  icon: Icons.picture_as_pdf_rounded,
                  label: "PDF",
                  subtitle: "Upload document",
                  onTap: _pickPdf,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildUploadCard(
                  icon: Icons.photo_library_rounded,
                  label: "Gallery",
                  subtitle: "Pick an image",
                  onTap: () => _pickImage(ImageSource.gallery),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildUploadCard(
                  icon: Icons.edit_calendar_rounded,
                  label: "Manual",
                  subtitle: "Build it yourself",
                  onTap: _skipToManualBuilder,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // File preview
          if (_selectedFileBytes != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
                color: Colors.green.withOpacity(0.05),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedMimeType == 'application/pdf' ? Icons.picture_as_pdf : Icons.image,
                    color: Colors.green,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFileName ?? 'File selected',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Ready for AI analysis',
                          style: TextStyle(color: Colors.green[700], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
          _buildContinueButton("Analyze with AI ✨", () {
            if (_selectedFileBytes == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select a timetable file first, or choose Manual")),
              );
              return;
            }
            _processWithAi();
          }, isDark),
        ],
      ),
    );
  }

  Widget _buildUploadCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final accentColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(height: 14),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 3: Processing / Loading
  // ==========================================
  Widget _buildStep3Processing(bool isDark) {
    final accentColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.15),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1 + (_pulseController.value * 0.05)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.auto_awesome, size: 50, color: accentColor),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            Text(
              "Analyzing your timetable...",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            Text(
              "AI is reading your schedule and extracting all classes, times, and locations.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(accentColor),
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
  Widget _buildStep4Confirm(bool isDark) {
    final accentColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);
    final selectedCount = _sessionSelected.where((s) => s).length;

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
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _goToStep(1),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back, size: 20, color: isDark ? Colors.white : Colors.black),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_parsedSessions.isEmpty ? "Build Classes" : "Confirm Classes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    Text(_parsedSessions.isEmpty ? "Add your classes manually" : "$selectedCount of ${_parsedSessions.length} sessions selected", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(_parsedSessions.isEmpty ? "✎ Manual Mode" : "✓ Parsed", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Sessions list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final day in sortedDays) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                  child: Text(
                    day.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: accentColor, letterSpacing: 1.5),
                  ),
                ),
                for (final idx in grouped[day]!)
                  _buildSessionCard(idx, isDark),
              ],
              
              if (_parsedSessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      "No classes added yet.\nTap 'Add Class' to start building.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              // Add class manually button
              Center(
                child: TextButton.icon(
                  onPressed: _showManualAddClassDialog,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text("Add Class Manually"),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),

              const SizedBox(height: 100), // Bottom padding for button
            ],
          ),
        ),

        // Bottom action
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8F9FE),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -4))],
          ),
          child: _buildContinueButton("Looks Good! Save ${selectedCount} classes", _saveAndFinish, isDark),
        ),
      ],
    );
  }

  Widget _buildSessionCard(int index, bool isDark) {
    final s = _parsedSessions[index];
    final isSelected = _sessionSelected[index];

    final colorOption = (s['moduleName'] ?? '').hashCode.abs() % 6;
    final colors = [
      const Color(0xFF2962FF),
      const Color(0xFF7B1FA2),
      const Color(0xFF00695C),
      const Color(0xFFEF6C00),
      const Color(0xFFC62828),
      const Color(0xFF2E7D32),
    ];
    final accent = colors[colorOption];

    return GestureDetector(
      onTap: () => setState(() => _sessionSelected[index] = !_sessionSelected[index]),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? accent.withOpacity(0.12) : accent.withOpacity(0.08))
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(18),
          border: Border(left: BorderSide(color: isSelected ? accent : Colors.grey, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s['moduleName'] ?? 'Unknown Module',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                      decoration: isSelected ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${s['startTime']} – ${s['endTime']}  •  ${s['location'] ?? 'TBD'}",
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  if (s['moduleCode'] != null && s['moduleCode'].toString().isNotEmpty)
                    Text(s['moduleCode'], style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey)),
                ],
              ),
            ),
            Checkbox(
              value: isSelected,
              onChanged: (v) => setState(() => _sessionSelected[index] = v ?? true),
              activeColor: accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton(String label, VoidCallback onTap, bool isDark) {
    final accentColor = isDark ? const Color(0xFF5C6BC0) : const Color(0xFF2962FF);
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        child: Text(label),
      ),
    );
  }

  // --- Manual Add Class Dialog ---
  Future<void> _showManualAddClassDialog() async {
    final moduleNameCtrl = TextEditingController();
    final moduleCodeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    String selectedDay = 'Monday';
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text("Add Class"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: moduleNameCtrl,
                      decoration: const InputDecoration(labelText: "Module Name", hintText: "e.g. Programming"),
                      textCapitalization: TextCapitalization.words,
                    ),
                    TextField(
                      controller: moduleCodeCtrl,
                      decoration: const InputDecoration(labelText: "Module Code (Optional)", hintText: "e.g. CS101"),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: "Room / Location", hintText: "e.g. Room A"),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      decoration: const InputDecoration(labelText: "Day"),
                      items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) => setModalState(() => selectedDay = val!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(startTime.format(context)),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: startTime);
                              if (picked != null) setModalState(() => startTime = picked);
                            },
                          ),
                        ),
                        const Text(" - "),
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(endTime.format(context)),
                            onPressed: () async {
                              final picked = await showTimePicker(context: context, initialTime: endTime);
                              if (picked != null) setModalState(() => endTime = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  onPressed: () {
                    if (moduleNameCtrl.text.trim().isEmpty) return;
                    
                    final newClass = {
                      'moduleName': moduleNameCtrl.text.trim(),
                      'moduleCode': moduleCodeCtrl.text.trim(),
                      'location': locationCtrl.text.trim().isEmpty ? 'TBD' : locationCtrl.text.trim(),
                      'day': selectedDay,
                      'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                      'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                      'weeks': [],
                    };

                    setState(() {
                      _parsedSessions.add(newClass);
                      _sessionSelected.add(true);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          }
        );
      }
    );
  }
}
