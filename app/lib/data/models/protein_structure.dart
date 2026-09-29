import "package:bio_flutter/protein_viewer.dart";

/// A parsed structure plus the mapping between game sequence positions (1-based indices into
/// the wildtype sequence) and the structure's residues, which use mmCIF author numbering.
class ProteinStructure {
  final MolecularStructure structure;
  final Map<int, ResidueKey> _keyByPosition;
  final Map<ResidueKey, int> _positionByKey;

  ProteinStructure({required this.structure, required Map<int, ResidueKey> keyByPosition})
    : _keyByPosition = Map.unmodifiable(keyByPosition),
      _positionByKey = Map.unmodifiable({for (final e in keyByPosition.entries) e.value: e.key});

  ResidueKey? keyAt(int position) => _keyByPosition[position];

  int? positionOf(ResidueKey key) => _positionByKey[key];

  /// Parses the backend's /structure response: trimmed mmCIF text and the position map.
  static Future<ProteinStructure> fromJson(Map<String, dynamic> json) async {
    final result = await MmcifParser.parse(json["cif"] as String);
    return ProteinStructure(
      structure: result.structure,
      keyByPosition: {
        for (final r in (json["residues"] as List<dynamic>).cast<Map<String, dynamic>>())
          r["position"] as int: ResidueKey(
            r["chain_id"] as String,
            ResidueId(r["auth_seq_id"] as int, r["insertion_code"] as String),
          ),
      },
    );
  }
}
