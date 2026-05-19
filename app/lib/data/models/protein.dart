class Protein {
  final String pdbId;
  final String name;
  final String wildtypeSequence;

  const Protein({required this.pdbId, required this.name, required this.wildtypeSequence});

  factory Protein.fromJson(Map<String, dynamic> json) => Protein(
    pdbId: json["pdb_id"] as String,
    name: json["name"] as String,
    wildtypeSequence: json["wildtype_sequence"] as String,
  );
}