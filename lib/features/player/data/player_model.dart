class PlayerModel {
  final String id;
  final String name;
  final int skillLevel;
  final int rating; // NEW (ELO)
  final int wins;
  final int losses;
  final DateTime createdAt;

  PlayerModel({
    required this.id,
    required this.name,
    required this.skillLevel,
    this.rating = 1000,
    this.wins = 0,
    this.losses = 0,
    required this.createdAt,
  });
}
