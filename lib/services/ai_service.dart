import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Timetable scanning via Firebase AI Logic (Gemini Developer API).
///
/// The Gemini API key lives in Firebase, not in the app, so it can't be
/// extracted from the APK. Enable it once in the Firebase console:
/// Build → AI Logic → Get started → Gemini Developer API.
class AiService {
  GenerativeModel? _model;

  /// firebase_ai ships for Android, iOS and macOS only. On Windows the
  /// timetable is scanned on the phone and arrives through sync.
  static bool get isSupported => kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  GenerativeModel get model {
    if (!isSupported) {
      throw UnsupportedError('Timetable scanning is available on the phone app. '
          'Scan it there — it syncs to this PC automatically.');
    }
    // Change the model here if you hit quota limits.
    return _model ??= FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
  }

  /// Parses a timetable from a file (image or PDF) using Gemini.
  /// Returns a list of parsed session maps.
  Future<List<Map<String, dynamic>>> parseTimetableFromFile({
    required Uint8List fileBytes,
    required String courseName,
    required String mimeType,
  }) async {
    final prompt = _buildPrompt(courseName);

    final response = await model.generateContent([
      Content.multi([
        TextPart(prompt),
        InlineDataPart(mimeType, fileBytes),
      ])
    ]);

    return _parseResponse(response.text ?? '');
  }

  String _buildPrompt(String courseName) {
    return '''
You are a highly intelligent timetable parsing assistant for university students. 
The user is studying: "$courseName" (Use this context to help understand abbreviations or module names).

CRITICAL VALIDATION STEP:
First, analyze the provided image or document. If it is NOT a timetable, schedule, or list of classes (e.g., if it is a random photo, a picture of an animal, unrelated text, etc.), you MUST return exactly the following empty JSON array and nothing else:
[]

If it IS a timetable, extract ALL class sessions and return them as a JSON array.
Each object in the array MUST have the following keys exactly:
- "moduleName": String (The name of the class/module, e.g. "Programming", "Data Science")
- "moduleCode": String (The course code if present, else "")
- "location": String (The room or location, e.g. "NAC 2.12" or "ONLINE")
- "day": String (The day of the week, e.g. "Monday")
- "startTime": String (In HH:MM format, 24-hour clock)
- "endTime": String (In HH:MM format, 24-hour clock)
- "weeks": [] (List of week numbers if specified, else [])

Rules:
- If the same module appears on multiple days, create separate entries for each day.
- If a module has both a lecture and tutorial/lab, create separate entries for each.
- Use 24-hour time format (e.g. 09:00 not 9:00 AM).
- Return ONLY the JSON array. No other text.
''';
  }

  List<Map<String, dynamic>> _parseResponse(String responseText) {
    // Clean up the response — Gemini sometimes wraps in code fences
    String cleaned = responseText.trim();

    // Remove markdown code fences if present
    if (cleaned.startsWith('```')) {
      // Remove opening fence (```json or ```)
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      // Remove closing fence
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3).trim();
      }
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      throw FormatException('Expected a JSON array, got ${decoded.runtimeType}');
    } catch (e) {
      throw FormatException('Failed to parse AI response: $e\n\nRaw response:\n$cleaned');
    }
  }
}
