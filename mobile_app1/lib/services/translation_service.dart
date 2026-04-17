import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  static Future<String> translate({
    required String text,
    required String targetLang,
  }) async {
    try {
      final url =
          "https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|$targetLang";

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translated = data["responseData"]?["translatedText"] as String?;
        if (translated != null && translated.isNotEmpty) {
          print("✅ Translated '$text' → '$translated' (lang: $targetLang)");
          return translated;
        }
      }

      print(
        "❌ Translation API failed: ${response.statusCode} - ${response.body}",
      );
      return text;
    } catch (e) {
      print("💥 Translation failed for '$text' → $targetLang: $e");
      return text;
    }
  }
}
