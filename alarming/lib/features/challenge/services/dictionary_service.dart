import 'package:http/http.dart' as http;
import 'wordle_dictionary.dart';

class DictionaryService {
  static const String _baseUrl = 'https://api.dictionaryapi.dev/api/v2/entries/en';

  /// Validates a word using the free Dictionary API.
  /// Returns true if the word exists, false otherwise.
  /// Falls back to the local dictionary if the API is unreachable.
  static Future<bool> validateWord(String word) async {
    if (word.isEmpty) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/${word.toLowerCase()}'),
      ).timeout(const Duration(seconds: 2)); // Short timeout for responsiveness
      
      if (response.statusCode == 200) {
        return true;
      } else if (response.statusCode == 404) {
        return false;
      }
      // On server error, fall through to local check
    } catch (e) {
      // On network error or timeout, fall through to local check
    }
    
    // Fallback to local dictionary
    // We also check the internal challenge word list just in case
    return validWordleWords.contains(word.toUpperCase());
  }
}
