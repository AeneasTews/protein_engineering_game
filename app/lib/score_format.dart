import "constants.dart";

/// A score as shown to players. The DMS score is presented as if it were a thermal stability
/// (°C) so the numbers read naturally; the value itself is unchanged.
String formatScore(double? score, {bool detailed = false}) {
  if (score == null) return "-";
  final places = detailed ? GameRules.scoreDecimalPlacesDetailed : GameRules.scoreDecimalPlaces;
  return "${score.toStringAsFixed(places)} ${GameRules.scoreUnit}";
}
