import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plan_db.dart';
import 'database.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();
  static const String _modelName = 'gemini-2.0-flash';

  // -------- SharedPreferences helpers --------
  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<String?> _readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // Public getters your UI can call
  Future<String?> getSavedMacroRecsText() =>
      _readString('macro_recs:last_text');
  Future<String?> getSavedMacroRecsWhen() =>
      _readString('macro_recs:last_time');

  Future<String?> getSavedAdviceToday() => _readString('advice:${_todayKey()}');
  Future<String?> getSavedAdviceWhen() => _readString('advice:last_time');

  // Save parsed macros to SharedPreferences and PlanDb for dashboard + plan screen.
  Future<void> _saveMacrosEverywhereFromText(String text) async {
    final goals = _parseGoalsFromText(text);
    if (goals == null) return;

    // SharedPreferences (optional quick access)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('macro_calories', goals.calories);
    await prefs.setInt('macro_protein', goals.protein);
    await prefs.setInt('macro_carbs', goals.carbs);
    await prefs.setInt('macro_fat', goals.fat);

    // SQLite persistence for source of truth
    await PlanDb.instance.saveGoals(goals);
  }

  /// Parse macro goals from a free-form text blob.
  MacroGoals? _parseGoalsFromText(String text) {
    int? cals = _firstIntMatch(
      RegExp(r'(?:calories|kcal)\D*(\d{2,5})', caseSensitive: false),
      text,
    );
    int? prot = _firstIntMatch(
      RegExp(r'(?:protein|prot)\D*(\d{1,4})', caseSensitive: false),
      text,
    );
    int? carbs = _firstIntMatch(
      RegExp(r'(?:carbs?|carbohydrates)\D*(\d{1,4})', caseSensitive: false),
      text,
    );
    int? fat = _firstIntMatch(
      RegExp(r'\bfat\D*(\d{1,4})', caseSensitive: false),
      text,
    );

    if (cals == null || prot == null || carbs == null || fat == null) {
      return null;
    }
    return MacroGoals(calories: cals, protein: prot, carbs: carbs, fat: fat);
  }

  int? _firstIntMatch(RegExp re, String s) {
    final m = re.firstMatch(s);
    if (m != null && m.groupCount >= 1) {
      return int.tryParse(m.group(1)!.replaceAll(',', ''));
    }
    return null;
  }

  /// Convenience: fetch profile from DB and return a bulleted list of macro recs.
  Future<String?> recommendMacrosFromDB({String? extraContext}) async {
    try {
      final profile = await DBHelper().getProfile();
      if (profile == null) {
        debugPrint('GeminiService: No profile found in DB');
        return null;
      }
      return recommendMacros(profile: profile, extraContext: extraContext);
    } catch (e) {
      debugPrint('GeminiService recommendMacrosFromDB error: $e');
      return null;
    }
  }

  Future<String?> recommendMacros({
    required Map<String, dynamic> profile,
    String? extraContext,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('GeminiService: missing GEMINI_API_KEY');
      return null;
    }
    try {
      final gender = (profile['gender'] ?? 'Unspecified').toString();
      final age = (profile['age'] ?? 0).toString();
      final sportsType = (profile['sportsType'] ?? 'Unspecified').toString();
      final weight = (profile['weight'] ?? 0.0).toString();
      final height = (profile['height'] ?? 0.0).toString();
      final ctx = (extraContext != null && extraContext.trim().isNotEmpty)
          ? "Context: ${extraContext.trim()}\n"
          : "";
      final userPrompt =
      '''
        You are a concise nutrition coach.
        
        Based on this user's profile, provide macro recommendations:
        Gender: $gender
        Age: $age
        Sports Type: $sportsType
        Weight (kg): $weight
        Height (cm): $height
        $ctx
        Rules:
        - Output ONLY a bulleted list (no heading, no intro, no numbering).
        - Each bullet: key/value style, ≤15 words.
        - Include these bullets in this order:
          • Maintenance calories — <kcal> (brief method)
          • Target calories — <kcal> (goal rationale)
          • Protein — <g/day> (~<g/kg>), food examples
          • Carbs — <g/day>, timing notes
          • Fats — <g/day>, sources
          • Fiber — <g/day>, sources
          • Hydration — <L/day>
        ''';

      final model = GenerativeModel(model: _modelName, apiKey: apiKey);
      final response = await model.generateContent([Content.text(userPrompt)]);

      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;
      await _saveMacrosEverywhereFromText(text);
      await _saveString('macro_recs:last_text', text);
      await _saveString(
        'macro_recs:last_time',
        DateTime.now().toIso8601String(),
      );
      return text;
    } catch (e) {
      debugPrint('GeminiService error: $e');
      return null;
    }
  }

  Future<String> generateDailyQuote() async {
    String todayKey() {
      final now = DateTime.now();
      return '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
    }

    final key = todayKey();

    // 1) Already saved today?
    final existing = await PlanDb.instance.getDailyQuote(key);
    if (existing != null && (existing['quote'] ?? '').isNotEmpty) {
      final q = existing['quote']!;
      final a = existing['author']!;
      return a.isEmpty ? q : '$q — $a';
    }

    // 2) Generate a short quote
    final apiKey =
        dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      // fallback if no API – store a local quote to keep UI working
      const fallback = "Small steps every day lead to big changes.";
      await PlanDb.instance.saveDailyQuote(key, fallback);
      return fallback;
    }

    final prompt = '''
Generate ONE short motivational quote (<= 20 words).
Format exactly:
"Quote text" — Author
If author unknown, omit "— Author" part.
No extra lines.
''';

    try {
      // If you added the fallback helper earlier, use: final text = await _generateWithFallback(prompt);
      final model = GenerativeModel(model: _modelName, apiKey: apiKey);
      final resp = await model.generateContent([Content.text(prompt)]);
      var text = (resp.text ?? '').trim();

      if (text.isEmpty) {
        text = "Believe in your next step."; // fallback
      }

      // Parse "quote — author" (author optional)
      String quote = text;
      String? author;
      final parts = text.split('—');
      if (parts.length >= 2) {
        quote = parts[0].trim().replaceAll(RegExp(r'^"+|"+$'), '');
        author = parts.sublist(1).join('—').trim();
      } else {
        quote = text.replaceAll(RegExp(r'^"+|"+$'), '');
      }

      await PlanDb.instance.saveDailyQuote(key, quote, author: author);
      return author == null || author.isEmpty ? quote : '$quote — $author';
    } catch (_) {
      const fallback = "Keep going, you’re closer than you think.";
      await PlanDb.instance.saveDailyQuote(key, fallback);
      return fallback;
    }
  }

  /// Get concise, actionable coaching advice.
  /// - `notes` is whatever the user typed in "Additional information".
  /// - It will include today's macro totals and goals (if available) for context.
  Future<String?> getAdvice(String notes) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('GeminiService: missing GEMINI_API_KEY');
      return null;
    }
    try {
      final extra = notes.trim().isEmpty ? '(no extra notes)' : notes.trim();
      final wantsNutrition = _looksLikeNutrition(extra);

      String prompt;

      if (wantsNutrition) {
        // Build nutrition context ONLY when needed
        String todayKey() {
          final now = DateTime.now();
          return '${now.year.toString().padLeft(4, '0')}-'
              '${now.month.toString().padLeft(2, '0')}-'
              '${now.day.toString().padLeft(2, '0')}';
        }

        final dateKey = todayKey();

        MacroGoals? goals;
        MacroTotals? totals;
        try {
          goals =
              await PlanDb.instance.getGoalsForDate(dateKey) ??
                  await PlanDb.instance.getGoals();
          totals = await PlanDb.instance.getDailyTotals(dateKey);
        } catch (_) {
          /* ignore DB errors for advice */
        }

        final goalsLine = (goals == null)
            ? 'Goals: (not set)'
            : 'Goals: Calories ${goals.calories}, Protein ${goals.protein}g, Carbs ${goals.carbs}g, Fat ${goals.fat}g';

        final totalsLine = (totals == null)
            ? 'Today: (no meals logged yet)'
            : 'Today so far: Calories ${totals.calories}, Protein ${totals.protein}g, Carbs ${totals.carbs}g, Fat ${totals.fat}g';

        prompt =
        '''
You are a concise, supportive fitness/nutrition coach. Provide specific, actionable nutrition advice the user can apply today.

Context:
- $goalsLine
- $totalsLine
- Additional info: $extra

Output:
- Up to 8 short bullets with clear actions (food swaps, timing, portions, hydration)
- If macros over/under, suggest a simple adjustment for the next meal
- End with 1 motivational one-liner
''';
      } else {
        // Non-nutrition: focus purely on what the user wrote
        prompt =
        '''
You are a concise, supportive coach. Provide specific, actionable advice based only on the user's notes below.
Avoid nutrition/macros unless explicitly requested.

User notes:
$extra

Output:
- Up to 8 short bullets with clear, practical actions
- Cover mindset, training ideas, habit tweaks, timeboxing, recovery as relevant
- End with 1 motivational one-liner
''';
      }

      // Use your existing model helper or direct call:
      // If you have _generateWithFallback(prompt): prefer that.
      final model = GenerativeModel(model: _modelName, apiKey: apiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        return 'I could not generate advice right now. Try again in a moment.';
      }

      // Optional: persist advice per day if you want
      final today = DateTime.now();
      await _saveString('advice:${today.toIso8601String().substring(0,10)}', text);
      await _saveString('advice:last_time', DateTime.now().toIso8601String());

      return text;
    } catch (e) {
      return 'Error getting advice: $e';
    }
  }

  bool _looksLikeNutrition(String s) {
    final q = s.toLowerCase();
    const keys = [
      'nutrition',
      'nutritional',
      'calorie',
      'calories',
      'kcal',
      'protein',
      'carb',
      'carbs',
      'fat',
      'macro',
      'macros',
      'diet',
      'meal',
      'meals',
      'eat',
      'eating',
      'deficit',
      'surplus',
      'bulk',
      'bulking',
      'cut',
      'cutting',
      'hydrate',
      'hydration',
      'water intake',
    ];
    return keys.any(q.contains);
  }
}
