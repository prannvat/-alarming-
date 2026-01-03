import 'dart:math';

class GeneralKnowledgeQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  GeneralKnowledgeQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

class GeneralKnowledgeChallenge {
  final String difficulty;

  GeneralKnowledgeChallenge({required this.difficulty});

  List<GeneralKnowledgeQuestion> generateQuestions({int count = 3}) {
    final allQuestions = [
      // Easy
      GeneralKnowledgeQuestion(
        question: "What is the capital of France?",
        options: ["London", "Berlin", "Paris", "Madrid"],
        correctIndex: 2,
      ),
      GeneralKnowledgeQuestion(
        question: "Which planet is known as the Red Planet?",
        options: ["Venus", "Mars", "Jupiter", "Saturn"],
        correctIndex: 1,
      ),
      GeneralKnowledgeQuestion(
        question: "What is 2 + 2?",
        options: ["3", "4", "5", "6"],
        correctIndex: 1,
      ),
      GeneralKnowledgeQuestion(
        question: "Who painted the Mona Lisa?",
        options: ["Van Gogh", "Picasso", "Da Vinci", "Michelangelo"],
        correctIndex: 2,
      ),
      GeneralKnowledgeQuestion(
        question: "What is the largest ocean on Earth?",
        options: ["Atlantic", "Indian", "Arctic", "Pacific"],
        correctIndex: 3,
      ),
      
      // Medium
      GeneralKnowledgeQuestion(
        question: "What is the chemical symbol for Gold?",
        options: ["Ag", "Au", "Fe", "Cu"],
        correctIndex: 1,
      ),
      GeneralKnowledgeQuestion(
        question: "In which year did World War II end?",
        options: ["1943", "1944", "1945", "1946"],
        correctIndex: 2,
      ),
      GeneralKnowledgeQuestion(
        question: "Who wrote 'Romeo and Juliet'?",
        options: ["Charles Dickens", "William Shakespeare", "Jane Austen", "Mark Twain"],
        correctIndex: 1,
      ),
      GeneralKnowledgeQuestion(
        question: "What is the hardest natural substance on Earth?",
        options: ["Gold", "Iron", "Diamond", "Platinum"],
        correctIndex: 2,
      ),
      GeneralKnowledgeQuestion(
        question: "Which country invented pizza?",
        options: ["France", "USA", "Italy", "Spain"],
        correctIndex: 2,
      ),

      // Hard
      GeneralKnowledgeQuestion(
        question: "What is the speed of light?",
        options: ["299,792 km/s", "300,000 km/s", "150,000 km/s", "1,080 km/h"],
        correctIndex: 0,
      ),
      GeneralKnowledgeQuestion(
        question: "Who developed the theory of relativity?",
        options: ["Isaac Newton", "Albert Einstein", "Nikola Tesla", "Galileo Galilei"],
        correctIndex: 1,
      ),
      GeneralKnowledgeQuestion(
        question: "What is the smallest prime number?",
        options: ["0", "1", "2", "3"],
        correctIndex: 2,
      ),
      GeneralKnowledgeQuestion(
        question: "Which element has the atomic number 1?",
        options: ["Helium", "Oxygen", "Hydrogen", "Carbon"],
        correctIndex: 2,
      ),
      GeneralKnowledgeQuestion(
        question: "What is the capital of Australia?",
        options: ["Sydney", "Melbourne", "Canberra", "Perth"],
        correctIndex: 2,
      ),
    ];

    // Filter by difficulty (simplified logic for now, just shuffling all)
    // In a real app, you'd filter based on difficulty level
    
    final random = Random();
    final shuffled = List<GeneralKnowledgeQuestion>.from(allQuestions)..shuffle(random);
    return shuffled.take(count).toList();
  }
}
