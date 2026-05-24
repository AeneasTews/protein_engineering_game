import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';
import "package:flutter/foundation.dart";

class MolstarController {
  late final WebViewController _webViewController;
  bool _isReady = false;

  void Function(int position)? onResidueSelected;

  MolstarController() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color.fromARGB(255, 255, 255, 0))
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _isReady = true,
        onWebResourceError: (error) {
          debugPrint('MolstarController WebView error: ${error.description}');
        },
      ));

    if (kIsWeb) {
      _webViewController.loadHtmlString("assets/molstar/viewer.html");
    } else {
      _webViewController.loadFlutterAsset("assets/molstar/viewer.html");
    }

    if(!kIsWeb) {
      _webViewController.addJavaScriptChannel(
        "ResidueSelected",
        onMessageReceived: (message) {
          final position = int.tryParse(message.message);
          if (position != null) onResidueSelected?.call(position);
        }
      );
    }
  }

  WebViewController get webViewController => _webViewController;

  Future<void> loadStructure(String pdbData) async {
    if (!_isReady) return;
    final encoded = base64Encode(utf8.encode(pdbData));
    await _run("loadStructure('$encoded')");
  }

  Future<void> highlightResidues(List<(int pos, String aa)> mutations) async {
    if (!_isReady) return;
    final positions = jsonEncode(mutations.map((m) => m.$1).toList());
    await _run('highlightResidues(\'$positions\')');
  }

  Future<void> focusResidue(int position) async {
    if (!_isReady) return;
    await _run('focusResidue($position)');
  }

  Future<void> clearHighlights() async {
    if (!_isReady) return;
    await _run('clearHighlights()');
  }

  Future<void> _run(String js) async {
    await _webViewController.runJavaScript(js);
  }
}