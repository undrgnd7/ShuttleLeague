/// Simple points engine.
/// Win = +3 points, Loss = +1 point, No play = +0.
/// Starting rating is 0.
class EloEngine {
  static const int pointsForWin = 3;
  static const int pointsForLoss = 1;

  /// Signature kept so existing callers compile unchanged.
  /// [opponentRating] is ignored — points are fixed.
  static int calculateNewRating({
    required int rating,
    required int opponentRating,
    required bool won,
  }) {
    return rating + (won ? pointsForWin : pointsForLoss);
  }
}
