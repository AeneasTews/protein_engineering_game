import "package:app/blocs/experiment/experiment_bloc.dart";
import "package:app/constants.dart";
import "package:app/data/models/protein.dart";
import "package:app/data/repositories/session_repository.dart";
import "package:app/widgets/sequence_panel.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";

const _protein = Protein(pdbId: "TEST", name: "TEST", wildtypeSequence: "ACDEFGH");

Color? _tileColor(WidgetTester tester, int position) {
  final tile = find.ancestor(of: find.text("$position"), matching: find.byType(ElevatedButton));
  return tester.widget<ElevatedButton>(tile).style?.backgroundColor?.resolve({});
}

void main() {
  testWidgets("sequence tiles use the 3D viewer's mutation and selection colors", (tester) async {
    final bloc = ExperimentBloc(sessionRepository: SessionRepository(baseUrl: "http://unused"))
      ..add(const ExperimentStart(sessionId: 1, protein: _protein))
      ..add(const MutationChange(position: 2, aminoAcid: "A"))
      ..add(const MutationChange(position: 4, aminoAcid: "A"));

    Future<void> pump(int? selected) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: bloc,
            child: SequencePanel(protein: _protein, selectedPosition: selected),
          ),
        ),
      ),
    );

    await tester.pump();
    await pump(5);
    expect(_tileColor(tester, 2), StructureStyle.mutationColor);
    expect(_tileColor(tester, 5), StructureStyle.selectionColor);
    expect(_tileColor(tester, 1), isNot(anyOf(StructureStyle.mutationColor, StructureStyle.selectionColor)));

    // As in the viewer, a selected mutated residue shows the selection color.
    await pump(4);
    expect(_tileColor(tester, 4), StructureStyle.selectionColor);

    // Closing a bloc never completes inside testWidgets' fake-async zone.
    await tester.runAsync(bloc.close);
  });
}
