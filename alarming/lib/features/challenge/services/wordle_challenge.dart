import 'dart:math';

class WordleChallenge {
  final String difficulty;
  late final String targetWord;
  late final int wordLength;
  late final int maxAttempts;

  // Word lists by difficulty
  static const List<String> easyWords = [
    'APPLE', 'BEACH', 'CHAIR', 'DANCE', 'EAGLE',
    'FLAME', 'GRAPE', 'HOUSE', 'IMAGE', 'JUICE',
    'KNIFE', 'LIGHT', 'MONEY', 'NIGHT', 'OCEAN',
    'PAINT', 'QUEEN', 'RIVER', 'STONE', 'TRAIN',
    'UNCLE', 'VOICE', 'WATER', 'YOUTH', 'ZEBRA',
    'BREAD', 'CREAM', 'DREAM', 'EARTH', 'FOCUS',
    'GIANT', 'HEART', 'IVORY', 'JOINT', 'KARMA',
    'LEMON', 'MAGIC', 'NOBLE', 'ORBIT', 'PROUD',
  ];

  static const List<String> mediumWords = [
    'BRAIN', 'CRANE', 'DWARF', 'FLAME', 'GHOST',
    'HASTE', 'IVORY', 'JAZZY', 'KNACK', 'LYMPH',
    'MIRTH', 'NYMPH', 'OXIDE', 'PRIZE', 'QUARK',
    'REALM', 'SWAMP', 'THUMB', 'ULTRA', 'VIGOR',
    'WRATH', 'XENON', 'YEARN', 'ZESTY', 'BLAZE',
    'CRISP', 'DWELL', 'FROWN', 'GLYPH', 'HASTY',
    'JOLLY', 'KAYAK', 'LUCKY', 'MANGO', 'NEXUS',
  ];

  static const List<String> hardWords = [
    'ABYSS', 'BLITZ', 'CRYPT', 'DWELT', 'EPOCH',
    'FJORD', 'GLYPH', 'HYPER', 'ICILY', 'JUMPY',
    'KNELT', 'LYMPH', 'MYRRH', 'NYMPH', 'ONYX',
    'PIXEL', 'QUAFF', 'RHYME', 'SYLPH', 'TRYST',
    'USURP', 'VEXED', 'WALTZ', 'XEROX', 'YACHT',
    'ZAPPY', 'BURNT', 'CHUNK', 'DRYLY', 'EXULT',
  ];

  // Valid words for checking (includes all word lists)
  static final Set<String> validWords = {
    ...easyWords,
    ...mediumWords,
    ...hardWords,
  };

  WordleChallenge({required this.difficulty}) {
    final random = Random();
    
    switch (difficulty) {
      case 'easy':
        targetWord = easyWords[random.nextInt(easyWords.length)];
        maxAttempts = 6;
        break;
      case 'hard':
        targetWord = hardWords[random.nextInt(hardWords.length)];
        maxAttempts = 5;
        break;
      default: // medium
        targetWord = mediumWords[random.nextInt(mediumWords.length)];
        maxAttempts = 6;
    }
    
    wordLength = targetWord.length;
  }

  bool isValidWord(String word) {
    // For simplicity, accept any 5-letter word
    // In a real app, you'd have a full dictionary
    return word.length == wordLength;
  }
}
