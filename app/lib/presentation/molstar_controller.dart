import "dart:convert";
import "package:webview_flutter/webview_flutter.dart";

class MolstarController {
  late final WebViewController _webViewController;
  bool _isReady = false;

  MolstarController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel("ResidueSelected", onMessageReceived: (message) {
        final position = int.tryParse(message.message);
        if (position != null && onResidueSelected != null) {
          onResidueSelected!(position);
        }
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _isReady = true;
        },
      ))
      ..loadFlutterAsset("assets/molstar/viewer.html");
  }

  void Function(int position) ? onResidueSelected;

  WebViewController get webviewController => _webViewController;

  Future<void> loadStructure(String pdbData) async {
    if (!_isReady) return;
    final encoded = base64Encode(utf8.encode(pdbData));
    await _runJs("loadStructure('$encoded')");
  }

  Future<void> highlightResidues(List<(int pos, String aa)> mutations) async {
    if (!_isReady) return;
    final positions = jsonEncode(mutations.map((m) => m.$1).toList());
    await _runJs("highlightResidues($positions)");
  }

  Future<void> focusResidue(int position) async {
    if (!_isReady) return;
    await _runJs("focusResidue($position)");
  }

  Future<void> clearHighlights() async {
    if (!_isReady) return;
    await _runJs("clearHighlights()");
  }

  Future<void> _runJs(String js) async {
    await _webViewController.runJavaScript(js);
  }
}