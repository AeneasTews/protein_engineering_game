// Checks that bio_flutter's mmCIF parser and the backend agree on residue identities: every
// sequence position the backend maps must resolve to a parsed residue of the wildtype amino acid.
// Needs a live backend: MUTATEIT_TEST_SERVER=http://localhost:8000 fvm flutter test test/structure_test.dart
import "dart:io";

import "package:app/data/repositories/protein_repository.dart";
import "package:bio_flutter/protein_viewer.dart";
import "package:flutter_test/flutter_test.dart";

const _threeToOne = {
  "ALA": "A", "ARG": "R", "ASN": "N", "ASP": "D", "CYS": "C", "GLN": "Q", "GLU": "E", "GLY": "G", "HIS": "H", //
  "ILE": "I", "LEU": "L", "LYS": "K", "MET": "M", "PHE": "F", "PRO": "P", "SER": "S", "THR": "T", "TRP": "W", //
  "TYR": "Y", "VAL": "V",
};

void main() {
  final server = Platform.environment["MUTATEIT_TEST_SERVER"];
  test(
    "every protein's structure parses and maps onto its wildtype sequence",
    skip: server == null ? "set MUTATEIT_TEST_SERVER to run against a live backend" : false,
    () async {
      final repository = ProteinRepository(baseUrl: server!);
      final proteins = await repository.getProteins();
      expect(proteins, isNotEmpty);

      for (final protein in proteins) {
        final structure = await repository.getStructure(protein.pdbId);
        final residues = <ResidueKey, Residue>{
          for (final chain in structure.structure.chains)
            for (final residue in chain.residues) ResidueKey(chain.id, residue.id): residue,
        };
        expect(residues, isNotEmpty, reason: protein.pdbId);

        var mapped = 0;
        for (var position = 1; position <= protein.wildtypeSequence.length; position++) {
          final key = structure.keyAt(position);
          if (key == null) continue;
          mapped++;
          final residue = residues[key];
          expect(residue, isNotNull, reason: "${protein.pdbId} position $position -> $key not parsed");
          expect(
            _threeToOne[residue!.name],
            protein.wildtypeSequence[position - 1],
            reason: "${protein.pdbId} position $position",
          );
          expect(structure.positionOf(key), position);
        }
        // Most of the sequence must be selectable in 3D.
        expect(mapped, greaterThan(protein.wildtypeSequence.length * 0.8), reason: protein.pdbId);

        // All of these are folded domains: header helices/strands must reach the parsed residues
        // (they didn't for 4G3O, whose label and author numbering differ).
        final labels = [for (final residue in residues.values) residue.secondaryStructure.name[0]].join();
        // ignore: avoid_print
        print("${protein.pdbId} $labels");
        expect(labels.replaceAll("l", "").length, greaterThan(labels.length * 0.2), reason: protein.pdbId);
      }
    },
  );
}
