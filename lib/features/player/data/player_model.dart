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
  /// A stand-in player used to fill a court when someone doesn't show up.
  /// Never earns/loses points — excluded from all scoring and leaderboards.
  final bool isJoker;

  PlayerModel({
    required this.id,
    required this.name,
    required this.skillLevel,
    this.rating = 0,
    this.wins = 0,
    this.losses = 0,
    required this.createdAt,
    this.gender = PlayerGender.male,
    this.isJoker = false,
  });
}
