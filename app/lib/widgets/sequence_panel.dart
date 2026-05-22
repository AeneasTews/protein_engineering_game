import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../data/models/protein.dart";

const aminoAcids = ["A", "R", "N", "D", "C", "E", "Q", "G", "H", "I", "L", "K", "M", "F", "P", "S", "T", "W", "Y", "V"];

class SequencePanel extends StatelessWidget {
  final Protein protein;

  const SequencePanel({super.key, required this.protein});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MutationBar(),
          Divider(),
          _SequenceEditor(protein: protein)
        ]
      )
    );
  }
}

class _MutationBar extends StatelessWidget {
  const _MutationBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExperimentBloc, ExperimentState>(
      builder: (context, state) {
        if (state is! ExperimentActive) return SizedBox.shrink();

        final mutations = state.currentMutations;
        if (mutations.isEmpty) {
          return Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              "No staged mutations",
              style: Theme.of(context).textTheme.titleMedium
            )
          );
        }

        return SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            itemCount: mutations.length,
            itemBuilder: (context, index) {
              final mutation = mutations[index];
              final label = "${state.protein.wildtypeSequence[mutation.$1 - 1]}${mutation.$1}${mutation.$2}";
              return _MutationTile(
                label: label,
                onRemove: () => {
                  context.read<ExperimentBloc>().add(MutationChange(position: mutation.$1, aminoAcid:mutation.$2))
                },
              );
            },
          )
        );
      }
    );
  }
}

class _MutationTile extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _MutationTile({super.key, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onRemove,
      style: ElevatedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: Size.zero,
        backgroundColor: Theme.of(context).colorScheme.onInverseSurface
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Icon(Icons.close)
        ]
      )
    );
  }
}

class _SequenceEditor extends StatelessWidget {
  final Protein protein;

  const _SequenceEditor({super.key, required this.protein});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExperimentBloc, ExperimentState>(
      builder: (context, state) {
        if (state is! ExperimentActive) return SizedBox.shrink();

        return Expanded(
          child: Padding(
            padding: EdgeInsetsGeometry.symmetric(horizontal: 3),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 50,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                mainAxisExtent: 50
              ),
              itemCount: protein.wildtypeSequence.length,
              itemBuilder: (context, index) {
                final position = index + 1;
                final wildtypeAa = protein.wildtypeSequence[index];
                final isMutated = state.currentMutations.any((m) => m.$1 == position);

                return _ResidueTile(position: position, wildtypeAa: wildtypeAa, isMutated: isMutated);
              },
            )
          )
        );
      }
    );
  }
}

class _ResidueTile extends StatelessWidget {
  final int position;
  final String wildtypeAa;
  final bool isMutated;
  
  const _ResidueTile({required this.position, required this.wildtypeAa, required this.isMutated});

  void _showAminoAcidPicker(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final experimentBloc = context.read<ExperimentBloc>();

    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        offset.dx + 400,
        0
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Text(
            "Position: $position; Wildtype: $wildtypeAa",
            style: Theme.of(context).textTheme.titleLarge
          )
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 400,
            height: 220,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5
              ),
              itemCount: 20,
              itemBuilder: (context, index) {
                final aminoAcid = aminoAcids[index];
                return ElevatedButton(
                  onPressed: () {
                    experimentBloc.add(MutationChange(position: position, aminoAcid: aminoAcid));
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(aminoAcid, style: Theme.of(context).textTheme.titleLarge),
                      if (aminoAcid == wildtypeAa)
                        Text(
                          "WT",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 8,
                            height: 0.8
                          )
                        )
                    ]
                  )
                );
              },
            )
          )
        )
      ]
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showAminoAcidPicker(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: isMutated ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.onInverseSurface,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BlocBuilder<ExperimentBloc, ExperimentState>(
            builder: (context, state) {
              if (state is! ExperimentActive || !isMutated) return Text(wildtypeAa, style: Theme.of(context).textTheme.titleLarge);
              final mutation = state.currentMutations.firstWhere((m) => m.$1 == position);
              return Text(mutation.$2, style: Theme.of(context).textTheme.titleLarge);
            }
          ),
          Text(
            position.toString(),
            style: Theme.of(context).textTheme.labelMedium,
            overflow: TextOverflow.ellipsis,
          )
        ]
      )
    );
  }
}