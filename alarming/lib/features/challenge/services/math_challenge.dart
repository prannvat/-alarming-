import 'dart:math';

class MathChallenge {
  final String difficulty;
  final Random _random = Random();

  MathChallenge({required this.difficulty});

  List<MathQuestion> generateQuestions({int count = 3}) {
    final questions = <MathQuestion>[];
    for (int i = 0; i < count; i++) {
      questions.add(_generateQuestion());
    }
    return questions;
  }

  MathQuestion _generateQuestion() {
    switch (difficulty) {
      case 'easy':
        return _generateEasyQuestion();
      case 'hard':
        return _generateHardQuestion();
      case 'medium':
      default:
        return _generateMediumQuestion();
    }
  }

  MathQuestion _generateEasyQuestion() {
    final operations = ['+', '-'];
    final operation = operations[_random.nextInt(operations.length)];
    
    int a = _random.nextInt(20) + 1; // 1-20
    int b = _random.nextInt(20) + 1; // 1-20
    
    // Ensure no negative results for subtraction
    if (operation == '-' && b > a) {
      final temp = a;
      a = b;
      b = temp;
    }
    
    final answer = operation == '+' ? a + b : a - b;
    final question = '$a $operation $b';
    
    return MathQuestion(
      question: question,
      answer: answer,
      difficulty: 'easy',
    );
  }

  MathQuestion _generateMediumQuestion() {
    final operations = ['+', '-', '×'];
    final operation = operations[_random.nextInt(operations.length)];
    
    if (operation == '×') {
      // Two-step problem: multiplication then addition/subtraction
      final a = _random.nextInt(15) + 1; // 1-15
      final b = _random.nextInt(10) + 1; // 1-10
      final c = _random.nextInt(20) + 1; // 1-20
      final secondOp = _random.nextBool() ? '+' : '-';
      
      final firstResult = a * b;
      final answer = secondOp == '+' ? firstResult + c : firstResult - c;
      final question = '($a × $b) $secondOp $c';
      
      return MathQuestion(
        question: question,
        answer: answer,
        difficulty: 'medium',
      );
    } else {
      // Simple two-number operation with larger numbers
      int a = _random.nextInt(50) + 10; // 10-60
      int b = _random.nextInt(50) + 10; // 10-60
      
      if (operation == '-' && b > a) {
        final temp = a;
        a = b;
        b = temp;
      }
      
      final answer = operation == '+' ? a + b : a - b;
      final question = '$a $operation $b';
      
      return MathQuestion(
        question: question,
        answer: answer,
        difficulty: 'medium',
      );
    }
  }

  MathQuestion _generateHardQuestion() {
    final types = ['square_root', 'exponent', 'complex'];
    final type = types[_random.nextInt(types.length)];
    
    switch (type) {
      case 'square_root':
        final perfectSquares = [4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144];
        final square = perfectSquares[_random.nextInt(perfectSquares.length)];
        final squareRoot = sqrt(square).toInt();
        final extra = _random.nextInt(20) + 1;
        final operation = _random.nextBool() ? '+' : '-';
        
        final answer = operation == '+' ? squareRoot + extra : squareRoot - extra;
        final question = '√$square $operation $extra';
        
        return MathQuestion(
          question: question,
          answer: answer,
          difficulty: 'hard',
        );
        
      case 'exponent':
        final base = _random.nextInt(8) + 2; // 2-10
        final exp = 2; // Keep it simple with squares
        final result = pow(base, exp).toInt();
        final extra = _random.nextInt(30) + 10;
        final operation = _random.nextBool() ? '+' : '-';
        
        final answer = operation == '+' ? result + extra : result - extra;
        final question = '$base² $operation $extra';
        
        return MathQuestion(
          question: question,
          answer: answer,
          difficulty: 'hard',
        );
        
      case 'complex':
      default:
        // Three-step problem
        final a = _random.nextInt(10) + 1;
        final b = _random.nextInt(10) + 1;
        final c = _random.nextInt(10) + 1;
        final d = _random.nextInt(10) + 1;
        
        final step1 = a * b;
        final step2 = c + d;
        final answer = step1 - step2;
        final question = '($a × $b) - ($c + $d)';
        
        return MathQuestion(
          question: question,
          answer: answer,
          difficulty: 'hard',
        );
    }
  }
}

class MathQuestion {
  final String question;
  final int answer;
  final String difficulty;

  MathQuestion({
    required this.question,
    required this.answer,
    required this.difficulty,
  });
}
