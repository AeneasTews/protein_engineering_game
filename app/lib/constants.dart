import "dart:ui" show Size;

import "package:bio_flutter/protein_viewer.dart" show CartoonStyle;
import "package:flutter/material.dart" show Color, Colors;

// ---------------------------------------------------------------------------
// Game rules
// ---------------------------------------------------------------------------

class GameRules {
  GameRules._();

  // Practice sessions; match sessions get their turn budget from the server.
  static const int maxTurns = 20;
  // The round counter switches to a warning color this many turns before the last.
  static const int turnWarningMargin = 2;

  // A score within +-this of 0 is still considered "essentially wildtype"
  // for coloring purposes.
  static const double wildtypeEquivalenceBand = 0.1;

  static const int scoreDecimalPlaces = 2;
  // Used only in the history chart's hover tooltip, which shows one more
  // digit of precision than the summary displays.
  static const int scoreDecimalPlacesDetailed = 3;
}

// ---------------------------------------------------------------------------
// Multiplayer
// ---------------------------------------------------------------------------

class Network {
  Network._();

  // Must match game/settings.py and game/discovery.py in the backend.
  static const int discoveryPort = 47800;
  static const String discoveryServiceName = "mutateit";
  static const int defaultServerPort = 8000;

  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration reconnectDelay = Duration(seconds: 2);
}

class MatchRules {
  MatchRules._();

  // The match clock switches to a warning color below this.
  static const Duration clockWarning = Duration(seconds: 30);
  static const Duration clockTick = Duration(milliseconds: 200);
}

// Why the submit button is locked during a match.
class MatchText {
  MatchText._();

  static const String getReady = "Get ready…";
  static const String outOfTurns = "Out of turns — waiting for opponent";
  static const String matchOver = "Match over";
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

class MatchLayout {
  MatchLayout._();

  static const double countdownFontSize = 160.0;
  static const double clockFontSize = 28.0;
  static const double connectionDotSize = 10.0;
  static const double resultWidth = 720.0;
  static const double lobbyPanelWidth = 360.0;
  static const double connectFormWidth = 420.0;
  static const Duration opponentToastDuration = Duration(seconds: 2);
}

class StructureViewerLayout {
  StructureViewerLayout._();

  static const double recenterButtonMargin = 12.0;
}

// ---------------------------------------------------------------------------
// 3D structure (bio_flutter's ProteinViewer)
// ---------------------------------------------------------------------------

class StructureStyle {
  StructureStyle._();

  // Matches bio_flutter's protein_viewer example: default cartoon colors (orange selection,
  // cyan hover), purple annotations, black outlines and pencil shading. Precedence in the
  // viewer is hover, then selection, then highlights (pending mutations), then secondary structure.
  static const Color mutationColor = Colors.purpleAccent;
  static const CartoonStyle cartoon = CartoonStyle(outlineColor: Colors.black, pencilTexture: true);
}
