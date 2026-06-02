import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/experiment/experiment_bloc.dart";
import "../blocs/protein_library/protein_library_bloc.dart";
import "../blocs/session_manager/session_manager_bloc.dart";
import "../data/models/highscore.dart";
import "../data/models/protein.dart";
import "../data/repositories/session_repository.dart";
import "game_screen.dart";

class ProteinLibraryScreen extends StatefulWidget {
  const ProteinLibraryScreen({super.key});

  @override
  State<ProteinLibraryScreen> createState() => _ProteinLibraryScreenState();
}

class _ProteinLibraryScreenState extends State<ProteinLibraryScreen> {
  final _usernameController = TextEditingController();

  @override
  dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<SessionManagerBloc, SessionManagerState>(
        listener: (context, state) {
          if (state is SessionManagerActive) {
            final libraryState = context.read<ProteinLibraryBloc>().state;
            if (libraryState is! ProteinLibraryLoaded) return;
            final protein = libraryState.proteins.firstWhere((p) => p.pdbId == libraryState.selectedPdbId);

            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (context) => ExperimentBloc(sessionRepository: context.read<SessionRepository>())..add(ExperimentStart(sessionId: state.sessionId, protein: protein)),
                child: GameScreen(protein: protein)
              ),
            ));
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: _ProteinGrid()
              )
            ),
            SizedBox(
              width: 400,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: _SessionPanel(usernameController: _usernameController)
                  ),
                  Spacer()
                ]
              )
            )
          ]
        )
      )
    );
  }
}

class _ProteinGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProteinLibraryBloc, ProteinLibraryState>(
      builder: (context, state) {
        if (state is ProteinLibraryLoading) return const Center(child: CircularProgressIndicator());

        if (state is ProteinLibraryError) {
          return Center(
            child: Column(
              children: [
                Text(state.message),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => context.read<ProteinLibraryBloc>().add(const ProteinLibraryStarted()),
                  child: const Text("Retry")
                )
              ]
            )
          );
        }

        if (state is ProteinLibraryLoaded) {
          return GridView.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  mainAxisExtent: 130
              ),
              itemCount: state.proteins.length,
              itemBuilder: (context, index) {
                final protein = state.proteins[index];
                final isSelected = state.selectedPdbId == protein.pdbId;
                final highscore = state.highscores[protein.pdbId];
                return _ProteinCard(
                  protein: protein,
                  isSelected: isSelected,
                  highscore: highscore,
                );
              }
          );
        }

        return const SizedBox.shrink();
      }
    );
  }
}

class _ProteinCard extends StatelessWidget {
  final Protein protein;
  final bool isSelected;
  final Highscore? highscore;

  const _ProteinCard({required this.protein, required this.isSelected, required this.highscore});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      elevation: isSelected ? 4 : 1,
      clipBehavior: Clip.antiAlias,
      shadowColor: isSelected ? Theme.of(context).colorScheme.primary : null,
      child: InkWell(
        onTap: () => {context.read<ProteinLibraryBloc>().add(ProteinSelected(protein.pdbId))},
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                protein.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary
                ),
                overflow: TextOverflow.ellipsis
              ),
              const SizedBox(height: 4),
              Text(protein.pdbId.toUpperCase(), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Text(
                "${protein.wildtypeSequence.length} AA",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                highscore != null ? "🏆 ${highscore!.username} ${highscore!.score.toStringAsFixed(2)}" : "🏆 —",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  overflow: TextOverflow.ellipsis
                )
              )
            ]
          )
        )
      )
    );
  }
}

class _SessionPanel extends StatelessWidget {
  final TextEditingController usernameController;

  const _SessionPanel({required this.usernameController});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProteinLibraryBloc, ProteinLibraryState>(
      builder: (context, libraryState) {
        final hasSelection = libraryState is ProteinLibraryLoaded && libraryState.selectedPdbId != null;
        
        return BlocBuilder<SessionManagerBloc, SessionManagerState>(
          builder: (context, sessionState) {
            final isLoading = sessionState is SessionManagerLoading;

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant
                ),

              ),
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        hintText: "Enter your name",
                        border: OutlineInputBorder()
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      hasSelection ? "Protein: ${libraryState.selectedPdbId!}" : "Select Protein",
                      style: Theme.of(context).textTheme.bodyLarge
                    ),

                    const SizedBox(height: 16),

                    FilledButton(
                      onPressed: () {
                        if (!hasSelection || isLoading) return;

                        final username = usernameController.text.trim();
                        if (username.isEmpty) return;

                        final pdbId = libraryState.selectedPdbId!;
                        context.read<SessionManagerBloc>().add(SessionManagerCreate(username: username, pdbId: pdbId));
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(8)),
                        minimumSize: Size(double.infinity, 45)
                      ),
                      child: isLoading ? const CircularProgressIndicator() : const Text("Start Experiment")
                    )
                  ]
                )
              )
            );
          }
        );
      }
    );
  }
}