enum SecondaryStructureType {
  loop,
  helix,
  sheet;

  static SecondaryStructureType fromJson(String value) => switch (value) {
    "loop" => SecondaryStructureType.loop,
    "helix" => SecondaryStructureType.helix,
    "sheet" => SecondaryStructureType.sheet,
    _ => throw FormatException("Unknown secondary_structure: $value"),
  };
}
