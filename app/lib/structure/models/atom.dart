import "package:vector_math/vector_math.dart";

class Atom {
  Atom({required this.element, required this.atomName, required this.position});

  final String element;
  final String atomName;
  final Vector3 position;

  factory Atom.fromJson(Map<String, dynamic> json) {
    return Atom(
      element: json["element"] as String,
      atomName: json["atom_name"] as String,
      position: Vector3((json["x"] as num).toDouble(), (json["y"] as num).toDouble(), (json["z"] as num).toDouble()),
    );
  }
}
