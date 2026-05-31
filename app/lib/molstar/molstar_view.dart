import "dart:js_interop";
import "dart:js_interop_unsafe";
import "package:flutter/material.dart";
import "dart:ui_web" as ui;
import "package:web/web.dart";
import "molstar_controller.dart";

class MolstarView extends StatefulWidget {
  final MolstarController controller;
  final String pdbId;
  final String wildtypeSequence;

  const MolstarView({
    super.key,
    required this.controller,
    required this.pdbId,
    required this.wildtypeSequence,
  });

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
      final bgColor = Theme.of(context).scaffoldBackgroundColor.toARGB32() & 0xFFFFFF;

      await Future.delayed(const Duration(milliseconds: 100));

      widget.controller.registerJsCallbacks();
      widget.controller.gymSequence = widget.wildtypeSequence;

      window.callMethod(
        "initializeMolstar".toJS,
        widget.pdbId.toJS,
        widget.wildtypeSequence.toJS,
        bgColor.toJS,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const HtmlElementView(viewType: "molstar-view");
  }
}