import "blocs/connect/connect_bloc.dart";
import "blocs/lobby/lobby_bloc.dart";
import "blocs/session_manager/session_manager_bloc.dart";
import "blocs/protein_library/protein_library_bloc.dart";
import "data/repositories/session_repository.dart";
import "data/services/lan_discovery.dart";
import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "config.dart";
import "data/repositories/protein_repository.dart";
import "widgets/connect_screen.dart";
import "widgets/lobby_screen.dart";
import "widgets/protein_library_screen.dart";

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  // The server is chosen at runtime, so everything that talks to it is created only once connected.
  ServerConnection? _connection;

  void _leave() {
    final connection = _connection;
    setState(() => _connection = null);
    connection?.matchRepository.dispose();
  }

  MaterialApp _materialApp(Widget home) => MaterialApp(
    title: "Protein Engineering Game",
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: home,
  );

  // The public web deployment stays single-player: browsers can't discover LAN servers, and
  // its proxy isn't set up for the multiplayer WebSocket.
  Widget _practiceOnlyApp() {
    const baseUrl = Config.apiBaseUrl;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => ProteinRepository(baseUrl: baseUrl)),
        RepositoryProvider(create: (_) => SessionRepository(baseUrl: baseUrl)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                ProteinLibraryBloc(proteinRepository: context.read<ProteinRepository>())..add(ProteinLibraryStarted()),
          ),
          BlocProvider(create: (context) => SessionManagerBloc(sessionRepository: context.read<SessionRepository>())),
        ],
        child: _materialApp(const ProteinLibraryScreen()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _practiceOnlyApp();

    final connection = _connection;
    if (connection == null) {
      return _materialApp(
        BlocProvider(
          create: (_) => ConnectBloc(discovery: LanDiscovery())..add(const ConnectStarted()),
          child: ConnectScreen(onConnected: (connection) => setState(() => _connection = connection)),
        ),
      );
    }

    final baseUrl = connection.baseUrl;
    return MultiRepositoryProvider(
      key: ObjectKey(connection),
      providers: [
        RepositoryProvider(create: (_) => ProteinRepository(baseUrl: baseUrl)),
        RepositoryProvider(create: (_) => SessionRepository(baseUrl: baseUrl)),
        RepositoryProvider.value(value: connection.matchRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                ProteinLibraryBloc(proteinRepository: context.read<ProteinRepository>())..add(ProteinLibraryStarted()),
          ),
          BlocProvider(create: (context) => SessionManagerBloc(sessionRepository: context.read<SessionRepository>())),
          BlocProvider(
            create: (_) => LobbyBloc(matchRepository: connection.matchRepository)..add(const LobbyStarted()),
          ),
        ],
        child: _materialApp(LobbyScreen(connection: connection, onLeave: _leave)),
      ),
    );
  }
}
