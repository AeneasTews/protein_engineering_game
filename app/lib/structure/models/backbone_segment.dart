import "package:vector_math/vector_math.dart";

import "molecular_structure.dart";
import "secondary_structure.dart";

class BackboneSegment {
  BackboneSegment({required this.type, required this.residues});

  final SecondaryStructureType type;

  final List<Residue> residues;

  List<Vector3> get alphaCarbonPositions => [for (final residue in residues) residue.alphaCarbon.position];
}

List<BackboneSegment> buildBackboneSegments(MolecularStructure structure) {
  final List<Residue> residues = structure.residues;
  if (residues.isEmpty) return [];

  final List<BackboneSegment> segments = [];
  SecondaryStructureType currentType = residues.first.secondaryStructure;
  List<Residue> current = [residues.first];

  void flush() {
    segments.add(BackboneSegment(type: currentType, residues: current));
  }

  for (int i = 1; i < residues.length; i++) {
    final Residue residue = residues[i];
    final Residue previous = residues[i - 1];
    final bool isContiguous = residue.position == previous.position + 1;

    if (residue.secondaryStructure == currentType && isContiguous) {
      current.add(residue);
    } else {
      flush();
      currentType = residue.secondaryStructure;
      current = [residue];
    }
  }
  flush();

  return segments;
}
