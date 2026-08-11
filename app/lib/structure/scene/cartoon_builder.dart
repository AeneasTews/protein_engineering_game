import "dart:math" as math;

import "package:flutter_scene/scene.dart";
import "package:vector_math/vector_math.dart";

import "../models/backbone_segment.dart";
import "../models/molecular_structure.dart";
import "../models/secondary_structure.dart";

class CartoonScene {
  CartoonScene({required this.nodes, required this.segmentForNode});

  final List<Node> nodes;
  final Map<Node, BackboneSegment> segmentForNode;
}

const double _loopRadius = 0.3;
const double _helixHalfWidth = 0.9;
const double _helixHalfThickness = 0.28;
const double _sheetHalfWidth = 0.8;
const double _sheetHalfThickness = 0.2;

List<Vector2> _flattenedEllipseProfile({
  required double halfWidth,
  required double halfThickness,
  int segments = 12,
}) {
  final List<Vector2> profile = [];
  for (int i = 0; i < segments; i++) {
    final double theta = 2 * math.pi * i / segments;
    profile.add(
      Vector2(halfThickness * math.cos(theta), halfWidth * math.sin(theta)),
    );
  }
  return profile;
}

Vector4 _colorFor(SecondaryStructureType type) => switch (type) {
  SecondaryStructureType.helix => Vector4(0.85, 0.25, 0.25, 1.0),
  SecondaryStructureType.sheet => Vector4(0.90, 0.80, 0.20, 1.0),
  SecondaryStructureType.loop => Vector4(0.80, 0.80, 0.80, 1.0),
};

CartoonScene buildCartoonScene(MolecularStructure structure) {
  final List<BackboneSegment> segments = buildBackboneSegments(structure);

  final List<Node> nodes = [];
  final Map<Node, BackboneSegment> segmentForNode = {};

  for (int i = 0; i < segments.length; i++) {
    final BackboneSegment segment = segments[i];
    final List<Vector3> points = List<Vector3>.of(segment.alphaCarbonPositions);

    if (i < segments.length - 1) {
      // add first position of next segement, such that segments will appear continues
      final BackboneSegment next = segments[i + 1];
      if (segment.residues.last.position + 1 == next.residues.first.position) {
        points.add(next.alphaCarbonPositions.first);
      }
    }

    if (points.length < 2) continue;

    final CatmullRomPath path = CatmullRomPath(points);
    final Geometry geometry = switch (segment.type) {
      SecondaryStructureType.loop => TubeGeometry(
        path,
        radius: _loopRadius,
        radialSegments: 8,
      ),
      SecondaryStructureType.helix => ExtrudeGeometry(
        path,
        profile: _flattenedEllipseProfile(
          halfWidth: _helixHalfWidth,
          halfThickness: _helixHalfThickness,
        ),
      ),
      SecondaryStructureType.sheet => ExtrudeGeometry(
        path,
        profile: _flattenedEllipseProfile(
          halfWidth: _sheetHalfWidth,
          halfThickness: _sheetHalfThickness,
        ),
      ),
    };

    final PhysicallyBasedMaterial material = PhysicallyBasedMaterial()
      ..baseColorFactor = _colorFor(segment.type)
      ..metallicFactor = 0.0
      ..roughnessFactor = 0.65
      ..doubleSided = true;
    final Node node = Node(mesh: Mesh(geometry, material));
    nodes.add(node);
    segmentForNode[node] = segment;
  }

  return CartoonScene(nodes: nodes, segmentForNode: segmentForNode);
}
