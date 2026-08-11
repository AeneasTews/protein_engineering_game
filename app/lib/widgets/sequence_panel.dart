import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../constants.dart";
import "../data/models/protein.dart";

class SequencePanel extends StatelessWidget {
  final Protein protein;

  final void Function(int position)? onResidueTap;

  const SequencePanel({super.key, required this.protein, this.onResidueTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MutationBar(),
          const Divider(),
          _SequenceEditor(protein: protein, onResidueTap: onResidueTap),
        ],
      ),
    );
  }
}

class _MutationBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExperimentBloc, ExperimentState>(
      builder: (context, state) {
        if (state is! ExperimentActive) return const SizedBox.shrink();

        final mutations = state.currentMutations;
        if (mutations.isEmpty) {
          return Container(
            height: SequenceGridLayout.mutationBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              "No staged mutations",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }

        return SizedBox(
          height: SequenceGridLayout.mutationBarHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            itemCount: mutations.length,
            itemBuilder: (context, index) {
              final mutation = mutations[index];
              final label =
                  "${state.protein.wildtypeSequence[mutation.$1 - 1]}${mutation.$1}${mutation.$2}";
              return _MutationTile(
                label: label,
                onRemove: () => context.read<ExperimentBloc>().add(
                  MutationChange(position: mutation.$1, aminoAcid: mutation.$2),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MutationTile extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _MutationTile({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onRemove,
      style: ElevatedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        minimumSize: Size.zero,
        backgroundColor: Theme.of(context).colorScheme.onInverseSurface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text(label), const Icon(Icons.close)],
      ),
    );
  }
}

class _SequenceEditor extends StatelessWidget {
  final Protein protein;
  final void Function(int position)? onResidueTap;

  const _SequenceEditor({required this.protein, this.onResidueTap});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExperimentBloc, ExperimentState>(
      builder: (context, state) {
        if (state is! ExperimentActive) return const SizedBox.shrink();

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: SequenceGridLayout.tileExtent,
                mainAxisSpacing: SequenceGridLayout.gridSpacing,
                crossAxisSpacing: SequenceGridLayout.gridSpacing,
                mainAxisExtent: SequenceGridLayout.tileExtent,
              ),
              itemCount: protein.wildtypeSequence.length,
              itemBuilder: (context, index) {
                final position = index + 1;
                final wildtypeAa = protein.wildtypeSequence[index];
                final isMutated = state.currentMutations.any(
                  (m) => m.$1 == position,
                );

                return _ResidueTile(
                  position: position,
                  wildtypeAa: wildtypeAa,
                  isMutated: isMutated,
                  onTap: () => onResidueTap?.call(position),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ResidueTile extends StatelessWidget {
  final int position;
  final String wildtypeAa;
  final bool isMutated;
  final VoidCallback? onTap;

  const _ResidueTile({
    required this.position,
    required this.wildtypeAa,
    required this.isMutated,
    this.onTap,
  });

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
        offset.dx + PickerMenuLayout.menuWidth,
        0,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          child: Text(
            "Position: $position  |  Wildtype: $wildtypeAa",
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: PickerMenuLayout.menuWidth,
            height: PickerMenuLayout.menuHeight,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: PickerMenuLayout.gridCrossAxisCount,
                mainAxisSpacing: PickerMenuLayout.gridSpacing,
                crossAxisSpacing: PickerMenuLayout.gridSpacing,
              ),
              itemCount: AminoAcids.all.length,
              itemBuilder: (context, index) {
                final aminoAcid = AminoAcids.all[index];
                return ElevatedButton(
                  onPressed: () {
                    experimentBloc.add(
                      MutationChange(position: position, aminoAcid: aminoAcid),
                    );
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UiLayout.cardBorderRadius),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        aminoAcid,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (aminoAcid == wildtypeAa)
                        Text(
                          "WT",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: PickerMenuLayout.wildtypeLabelFontSize,
                            height: PickerMenuLayout.wildtypeLabelLineHeight,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        onTap?.call();
        _showAminoAcidPicker(context);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isMutated
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.onInverseSurface,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiLayout.cardBorderRadius),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BlocBuilder<ExperimentBloc, ExperimentState>(
            builder: (context, state) {
              if (state is! ExperimentActive || !isMutated) {
                return Text(
                  wildtypeAa,
                  style: Theme.of(context).textTheme.titleLarge,
                );
              }
              final mutation = state.currentMutations.firstWhere(
                (m) => m.$1 == position,
              );
              return Text(
                mutation.$2,
                style: Theme.of(context).textTheme.titleLarge,
              );
            },
          ),
          Text(
            position.toString(),
            style: Theme.of(context).textTheme.labelMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
