import "package:app/score_format.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("scores are shown as a temperature", () {
    expect(formatScore(1.234), "1.23 °C");
    expect(formatScore(-0.5, detailed: true), "-0.500 °C");
    expect(formatScore(null), "-");
  });
}
