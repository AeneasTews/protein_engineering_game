import "dart:convert";
import "dart:js_interop";
import "dart:js_interop_unsafe";
import "package:web/web.dart";

class MolstarController {
  bool isLoaded = true;
  String? gymSequence;

  void Function(int seqPosition, String eventType, double x, double y)? onResidueEvent;

  void registerJsCallbacks() {
    window.setProperty(
      "onMolstarEvent".toJS,
      ((JSNumber seqPosition, JSString eventType, JSNumber x, JSNumber y) {
        onResidueEvent?.call(
          seqPosition.toDartInt,
          eventType.toDart,
          x.toDartDouble,
          y.toDartDouble,
        );
      }).toJS,
    );
  }

  void loadPdb(String pdbId) {
    if (gymSequence != null) {
      window.callMethod("loadPdb".toJS, pdbId.toJS, gymSequence!.toJS);
    } else {
      window.callMethod("loadPdb".toJS, pdbId.toJS);
    }
    isLoaded = true;
  }

  void selectResidue(int seqPosition) {
    if (!isLoaded) return;
    window.callMethod("selectResidue".toJS, seqPosition.toJS);
  }

  void highlightResidue(int seqPosition) {
    if (!isLoaded) return;
    window.callMethod("highlightResidue".toJS, seqPosition.toJS);
  }

  void updateMutationColors(List<int> seqPositions) {
    if (!isLoaded) return;
    final json = jsonEncode(seqPositions);
    window.callMethod("updateMutationColors".toJS, json.toJS);
  }

  void clearHighlight() {
    if (!isLoaded) return;
    window.callMethod("clearHighlight".toJS);
  }
}