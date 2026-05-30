import "dart:js_interop";
import "dart:js_interop_unsafe";
import "package:flutter/cupertino.dart";
import "dart:ui_web" as ui;
import "package:web/web.dart";
import "molstar_controller.dart";

class MolstarView extends StatefulWidget {
  final MolstarController controller;
  final String pdbId;

  const MolstarView({super.key, required this.controller, required this.pdbId});

  @override
  State<MolstarView> createState() => _MolstarViewState();
}

class _MolstarViewState extends State<MolstarView> {
  final String viewType = "molstar-view";

  @override
  void initState() {
    super.initState();

    ui.platformViewRegistry.registerViewFactory(
      viewType,
        (int viewId) {
          return HTMLDivElement()
              ..id = "molstar-container"
              ..style.width = "100%"
              ..style.height = "100%";
        }
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 100));

      widget.controller.registerJsCallbacks();
      window.callMethod("initializeMolstar".toJS, widget.pdbId.toJS);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: "molstar-view");
  }
}