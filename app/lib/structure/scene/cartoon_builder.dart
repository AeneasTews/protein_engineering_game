import "dart:math" as math;

import "package:flutter_scene/scene.dart";
import "package:vector_math/vector_math.dart";

import "../../constants.dart";
import "../models/backbone_segment.dart";
import "../models/molecular_structure.dart";
import "../models/secondary_structure.dart";

class CartoonScene {
  CartoonScene({required this.nodes, required this.segmentForNode});

  final List<Node> nodes;
  final Map<Node, BackboneSegment> segmentForNode;
}

List<Vector2> _flattenedEllipseProfile({
  required double halfWidth,
  required double halfThickness,
  int segments = CartoonGeometry.ellipseProfileSegments,
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
  SecondaryStructureType.helix => CartoonColors.helix,
  SecondaryStructureType.sheet => CartoonColors.sheet,
  SecondaryStructureType.loop => CartoonColors.loop,
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
        radius: CartoonGeometry.loopRadius,
        radialSegments: CartoonGeometry.loopRadialSegments,
      ),
      SecondaryStructureType.helix => ExtrudeGeometry(
        path,
        profile: _flattenedEllipseProfile(
          halfWidth: CartoonGeometry.helixHalfWidth,
          halfThickness: CartoonGeometry.helixHalfThickness,
        ),
      ),
      SecondaryStructureType.sheet => ExtrudeGeometry(
        path,
        profile: _flattenedEllipseProfile(
          halfWidth: CartoonGeometry.sheetHalfWidth,
          halfThickness: CartoonGeometry.sheetHalfThickness,
        ),
      ),
    };

    final PhysicallyBasedMaterial material = PhysicallyBasedMaterial()
      ..baseColorFactor = _colorFor(segment.type)
      ..metallicFactor = CartoonGeometry.materialMetallic
      ..roughnessFactor = CartoonGeometry.materialRoughness
      ..doubleSided = true;
    final Node node = Node(mesh: Mesh(geometry, material));
    nodes.add(node);
    segmentForNode[node] = segment;
  }

  return CartoonScene(nodes: nodes, segmentForNode: segmentForNode);
}
