import "widgets/protein_library_screen.dart";
import "blocs/session_manager/session_manager_bloc.dart";
import "blocs/protein_library/protein_library_bloc.dart";
import "data/repositories/session_repository.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "data/repositories/protein_repository.dart";

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const baseUrl = "http://localhost:8000";

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => ProteinRepository(baseUrl: baseUrl)),
        RepositoryProvider(create: (_) => SessionRepository(baseUrl: baseUrl))
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ProteinLibraryBloc(proteinRepository: context.read<ProteinRepository>())..add(ProteinLibraryStarted())
          ),
          BlocProvider(
            create: (context) => SessionManagerBloc(sessionRepository: context.read<SessionRepository>())
          )
        ],
        child: MaterialApp(
          title: "Protein Engineering Game",
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: const ProteinLibraryScreen(),
        )
      )
    );
  }
}