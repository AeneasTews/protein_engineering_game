class Highscore {
  final String username;
  final double score;

  const Highscore({required this.username, required this.score});

  factory Highscore.fromJson(Map<String, dynamic> json) => Highscore(
    username: json["username"] as String,
    score: (json["score"] as num).toDouble(),
  );
}