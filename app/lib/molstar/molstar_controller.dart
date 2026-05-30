import "dart:js_interop";
import "dart:js_interop_unsafe";
import "package:web/web.dart";

class MolstarController {
  bool isLoaded = true;

  void Function(String chain, int residue, String eventType)? onResidueEvent;

  void registerJsCallbacks() {
    window.setProperty(
      "onMolstarEvent".toJS,
      ((JSString chain, JSNumber residueId, JSString eventType) {
        onResidueEvent?.call(
          chain.toDart,
          residueId.toDartInt,
          eventType.toDart
        );
      }).toJS
    );
  }

  void loadPdb(String pdbId) {
    window.callMethod("loadPdb".toJS, pdbId.toJS);
    isLoaded = true;
  }

  void highlightResidue(String chain, int res) {
    if (!isLoaded) return;
    window.callMethod("highlightResidue".toJS, chain.toJS, res.toJS);
  }

  void clearHighlight() {
    window.callMethod("clearHighlight".toJS);
  }
}