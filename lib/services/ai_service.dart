import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiService {
  GenerativeModel? _model;

  GenerativeModel get model {
    if (_model == null) {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty || apiKey == 'your_api_key_here') {
        throw Exception('GEMINI_API_KEY not set in .env file. Get a free key from https://aistudio.google.com/apikey');
      }
      // You can change the model here if you run into quota issues or want a smarter model.
      // E.g., 'gemini-1.5-pro' or 'gemini-2.0-flash'.
      // 1.5-flash is highly reliable and generous for free-tier users.
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: apiKey,
      );
    }
    return _model!;
  }

  /// Parses a timetable from a file (image or PDF) using Gemini Vision.
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
        DataPart(mimeType, fileBytes),
      ])
    ]);

    return _parseResponse(response.text ?? '');
  }



  String _buildPrompt(String courseName) {
    return '''
You are a university timetable parser. The student is studying "$courseName".

Parse the timetable and extract EVERY class/lecture/tutorial/lab session.

Return ONLY a valid JSON array (no markdown, no explanation, no code fences). Each element must have:
{
  "day": "Monday",           // Full day name (Monday-Sunday)
  "startTime": "09:00",     // 24-hour format HH:mm
  "endTime": "12:00",       // 24-hour format HH:mm
  "moduleName": "...",      // Full module/subject name
  "moduleCode": "...",      // Module code if visible, else ""
  "location": "...",        // Room/location if visible, else "TBD"
  "mode": "CAMPUS",         // "CAMPUS" or "ONLINE" if distinguishable, else "CAMPUS"
  "weeks": []               // List of week numbers if specified, else [] (meaning every week)
}

Rules:
- If the same module appears on multiple days, create separate entries for each day.
- If a module has both a lecture and tutorial/lab, create separate entries for each.
- If online vs campus variants exist for different weeks, create separate entries with the appropriate weeks list.
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
