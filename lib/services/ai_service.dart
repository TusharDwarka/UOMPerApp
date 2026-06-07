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
