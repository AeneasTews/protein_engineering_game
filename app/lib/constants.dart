import "dart:math" as math;
import "dart:ui" show Size;

import "package:vector_math/vector_math.dart";

// ---------------------------------------------------------------------------
// Game rules
// ---------------------------------------------------------------------------

class GameRules {
  GameRules._();

  static const int maxTurns = 20;
  // The bar at which the round counter switches to a warning color.
  static const int turnWarningThreshold = maxTurns - 2;

  // A score within +-this of 0 is still considered "essentially wildtype"
  // for coloring purposes.
  static const double wildtypeEquivalenceBand = 0.1;

  static const int scoreDecimalPlaces = 2;
  // Used only in the history chart's hover tooltip, which shows one more
  // digit of precision than the summary displays.
  static const int scoreDecimalPlacesDetailed = 3;
}

class AminoAcids {
  AminoAcids._();

  static const List<String> all = [
    "A",
    "R",
    "N",
    "D",
    "C",
    "E",
    "Q",
    "G",
    "H",
    "I",
    "L",
    "K",
    "M",
    "F",
    "P",
    "S",
    "T",
    "W",
    "Y",
    "V",
  ];
}

class ExternalLinks {
  ExternalLinks._();

  static const String impressum = "https://biocentral.cloud/";
}

// ---------------------------------------------------------------------------
// Shared widget layout
// ---------------------------------------------------------------------------

class UiLayout {
  UiLayout._();

  // Rounded-corner radius used on cards, buttons, and picker-menu items
  // throughout the app.
  static const double cardBorderRadius = 8.0;
  static const Size fullWidthButtonSize = Size(double.infinity, 45);

  static const double historyChartAspectRatio = 1.75;
  static const double chartAxisReservedSize = 30.0;
  // Vertical headroom added above/below the min/max score on the history
  // chart's Y axis.
  static const double chartScorePadding = 1.0;
  static const double chartGridInterval = 1.0;
}

// The amino-acid picker menu popped up both from a sequence-panel tile
// (sequence_panel.dart) and from a click on the 3D structure
// (game_screen.dart) -- same grid, same sizing, same item styling.
class PickerMenuLayout {
  PickerMenuLayout._();

  static const int gridCrossAxisCount = 5;
  static const double gridSpacing = 5.0;
  static const double menuWidth = 400.0;
  static const double menuHeight = 220.0;
  static const double wildtypeLabelFontSize = 8.0;
  static const double wildtypeLabelLineHeight = 0.8;

  // Only used when the menu is anchored to a raw tap point (a click on the
  // 3D structure) rather than to a tile's own bounding box, so the menu
  // doesn't appear directly under the pointer.
  static const double cursorOffset = 8.0;
}

class SequenceGridLayout {
  SequenceGridLayout._();

  static const double tileExtent = 50.0;
  static const double gridSpacing = 5.0;
  static const double mutationBarHeight = 40.0;
}

class ProteinLibraryLayout {
  ProteinLibraryLayout._();

  static const double sidebarWidth = 400.0;
  static const double cardMaxExtent = 200.0;
  static const double cardSpacing = 5.0;
  static const double cardHeight = 130.0;
  static const double selectedCardElevation = 4.0;
  static const double unselectedCardElevation = 1.0;
}

class GameLayout {
  GameLayout._();

  static const double minPanelFraction = 0.15;
  static const double initialLeftFraction = 0.2;
  static const double initialMidFraction = 0.6;
  static const double dividerWidth = 8.0;
  static const double dividerLineWidth = 1.0;
  static const double finishDialogWidth = 340.0;
  static const double gameBarHeight = 50.0;
  static const double gameBarHorizontalPadding = 20.0;
}

class StructureViewerLayout {
  StructureViewerLayout._();

  static const double recenterButtonMargin = 12.0;
}

// ---------------------------------------------------------------------------
// 3D scene
// ---------------------------------------------------------------------------

class CameraLayout {
  CameraLayout._();

  static const double minPitch = -math.pi / 2 + 0.05;
  static const double maxPitch = math.pi / 2 - 0.05;
  static const double defaultYaw = 0.4;
  static const double defaultPitch = 0.35;
  static const double defaultMinDistance = 0.5;
  static const double defaultMaxDistance = 10000.0;

  static const double orbitSensitivity = 0.01;
  static const double zoomFactorMin = 0.8;
  static const double zoomFactorMax = 1.2;
  static const double scrollZoomSensitivity = 0.001;

  static const double fovNearMinimum = 0.05;
  static const double fovNearDistanceFactor = 0.01;
  static const double fovFarDistanceFactor = 20.0;
  static const double fovFarBase = 100.0;

  // Initial framing when a structure loads: how far back the camera starts,
  // and how close it's allowed to zoom in, both relative to the structure's
  // bounding-sphere radius.
  static const double initialDistanceFactor = 2.4;
  static const double minDistanceFactor = 0.05;
  // Used only when a structure has no residues to compute a real bounding
  // sphere from.
  static const double fallbackBoundingRadius = 50.0;
}

class CartoonGeometry {
  CartoonGeometry._();

  static const double loopRadius = 0.3;
  static const double helixHalfWidth = 0.9;
  static const double helixHalfThickness = 0.28;
  static const double sheetHalfWidth = 0.8;
  static const double sheetHalfThickness = 0.2;

  static const int ellipseProfileSegments = 12;
  static const int loopRadialSegments = 8;

  static const double materialRoughness = 0.65;
  static const double materialMetallic = 0.0;
}

// Vector4 has no const constructor, so these are static final rather than
// static const, unlike the rest of this file.
class CartoonColors {
  CartoonColors._();

  static final Vector4 helix = Vector4(0.85, 0.25, 0.25, 1.0);
  static final Vector4 sheet = Vector4(0.90, 0.80, 0.20, 1.0);
  static final Vector4 loop = Vector4(0.80, 0.80, 0.80, 1.0);
}

class MarkerLayout {
  MarkerLayout._();

  static const double selectionRadius = 1.3;
  static const double mutationRadius = 0.9;
}

class MarkerColors {
  MarkerColors._();

  static final Vector4 selection = Vector4(0.1, 0.95, 0.95, 1.0);
  static final Vector4 mutation = Vector4(1.0, 0.55, 0.0, 1.0);
}

class SceneLighting {
  SceneLighting._();

  static final Vector3 directionalLightDirection = Vector3(-0.4, -1.0, -0.3);
}
