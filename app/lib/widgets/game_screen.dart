import "package:app/blocs/experiment/experiment_bloc.dart";
import "package:app/widgets/history_panel.dart";
import "package:app/widgets/sequence_panel.dart";
import "package:app/widgets/structure_panel.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/session_manager/session_manager_bloc.dart";
import "../data/models/protein.dart";

class GameScreen extends StatelessWidget {
  final Protein protein;

  const GameScreen({super.key, required this.protein});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExperimentBloc, ExperimentState>(
      listenWhen: (_, nextState) => nextState is ExperimentFinished,
      listener: (context, state) {
        if (state is! ExperimentFinished) return;
        // TODO: show finished dialog
        Navigator.of(context).pop();
        context.read<SessionManagerBloc>().add(SessionManagerClose());
      },
      child: Scaffold(
        body: Column(
          children: [
            _GameBar(protein: protein),
            Divider(),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: SequencePanel(protein: protein)),
                  const VerticalDivider(),
                  Expanded(child: StructurePanel()),
                  const VerticalDivider(),
                  Expanded(child: HistoryPanel())
                ]
              )
            )
          ]
        )
      )
    );
  }
}

class _GameBar extends StatelessWidget {
  final Protein protein;

  const _GameBar({super.key, required this.protein});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            protein.name,
            style: Theme.of(context).textTheme.titleLarge
          ),
          const SizedBox(width: 10),
          Text(
            protein.pdbId,
            style: Theme.of(context).textTheme.titleLarge
          ),
          const Spacer(),
          BlocBuilder<ExperimentBloc, ExperimentState>(
            builder: (context, state) {
              if (state is! ExperimentActive) return SizedBox.shrink();
              return Row(
                children: [
                  Text(
                    "ROUND",
                    style: Theme.of(context).textTheme.titleLarge
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${state.turnCount} / 20",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: state.turnCount >= 18 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary
                    )
                  )
                ]
              );
            }
          )
        ]
      )
    );
  }
}