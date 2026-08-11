import "atom.dart";
import "secondary_structure.dart";

class Residue {
  Residue({
    required this.position,
    required this.name,
    required this.secondaryStructure,
    required this.alphaCarbon,
  });

  final int position;
  final String name;
  final SecondaryStructureType secondaryStructure;
  final Atom alphaCarbon;

  factory Residue.fromJson(Map<String, dynamic> json) {
    return Residue(
      position: json["position"] as int,
      name: json["name"] as String,
      secondaryStructure: SecondaryStructureType.fromJson(
        json["secondary_structure"] as String,
      ),
      alphaCarbon: Atom.fromJson(json["atom"] as Map<String, dynamic>),
    );
  }
}

class MolecularStructure {
  MolecularStructure({required this.residues});

  final List<Residue>
  residues; // could be less than actual number of residues --> go by Residue.poisition, not list index

  factory MolecularStructure.fromJson(Map<String, dynamic> json) {
    return MolecularStructure(
      residues: [
        for (final residue in json["residues"] as List)
          Residue.fromJson(residue as Map<String, dynamic>),
      ],
    );
  }
}
