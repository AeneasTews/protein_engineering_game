import 'package:app/data/models/trajectory_step.dart';

class ExperimentEntry extends TrajectoryStep {
  final List<(int pos, String aa)> mutations;

  ExperimentEntry._({required this.mutations, required super.mutant, required super.score, required super.turnCount});

  factory ExperimentEntry({required String mutant, required double score, required int turnCount}) {
    final List<(int pos, String aa)> parsedMutations = mutant.split(":").map((m) {
      final String aminoAcid = m[m.length - 1];
      final int position = int.parse(m.substring(1, m.length - 1));
      return (position, aminoAcid);
    }).toList();

    return ExperimentEntry._(mutations: parsedMutations, mutant: mutant, score: score, turnCount: turnCount);
  }
}