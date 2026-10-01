import "package:flutter/foundation.dart" show kIsWeb;

class Config {
  static const String apiBaseUrl = String.fromEnvironment("API_BASE_URL", defaultValue: "http://localhost:8000");
  static const bool _apiBaseUrlGiven = bool.hasEnvironment("API_BASE_URL");

  // Multiplayer (connect screen and lobby). On by default on desktop; web builds opt in with
  // --dart-define=MULTIPLAYER=true, so the public single-player web deployment is unaffected.
  static const bool multiplayer = bool.fromEnvironment("MULTIPLAYER", defaultValue: !kIsWeb);

  /// Pre-filled on the connect screen: API_BASE_URL if given, otherwise in a browser the origin
  /// that served the page (the backend can serve the web build itself), else localhost.
  static String get defaultServerAddress => kIsWeb && !_apiBaseUrlGiven ? Uri.base.origin : apiBaseUrl;
}
