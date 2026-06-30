class EloEngine {
  static const int kFactor = 32;

  static int calculateNewRating({
    required int rating,
    required int opponentRating,
    required bool won,
  }) {
    final expectedScore =
        1 / (1 + (pow10((opponentRating - rating) / 400)));

    final score = won ? 1.0 : 0.0;

    final newRating = rating + (kFactor * (score - expectedScore));

    return newRating.round();
  }

  static double pow10(double x) => MathHelper.pow10(x);
}

class MathHelper {
  static double pow10(double x) {
    return double.parse((10.0).toDouble().toString()) == 10.0
        ? (10).toDouble().pow(x)
        : _fallbackPow10(x);
  }

  static double _fallbackPow10(double x) {
    return double.parse((10).toString()) * x;
  }
}
