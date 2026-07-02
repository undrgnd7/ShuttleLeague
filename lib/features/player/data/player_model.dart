enum PlayerGender { male, female }

class PlayerModel {
  final String id;
  final String name;
  final int skillLevel;
  final int rating; // total points: Win=+3, Loss=+1, starts at 0
  final int wins;
  final int losses;
  final DateTime createdAt;
  final PlayerGender gender;

  PlayerModel({
    required this.id,
    required this.name,
    required this.skillLevel,
    this.rating = 0,
    this.wins = 0,
    this.losses = 0,
    required this.createdAt,
    this.gender = PlayerGender.male,
  });
}
