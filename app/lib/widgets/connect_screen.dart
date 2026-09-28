import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/connect/connect_bloc.dart";
import "../constants.dart";

class ConnectScreen extends StatefulWidget {
  final ValueChanged<ServerConnection> onConnected;

  const ConnectScreen({super.key, required this.onConnected});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _nicknameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nicknameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _connect() {
    context.read<ConnectBloc>().add(
      ConnectRequested(address: _addressController.text, nickname: _nicknameController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return MultiBlocListener(
      listeners: [
        BlocListener<ConnectBloc, ConnectState>(
          listenWhen: (prev, next) => !prev.preferencesLoaded && next.preferencesLoaded,
          listener: (context, state) {
            if (_nicknameController.text.isEmpty) _nicknameController.text = state.savedNickname;
            if (_addressController.text.isEmpty) _addressController.text = state.savedAddress;
          },
        ),
        BlocListener<ConnectBloc, ConnectState>(
          listenWhen: (prev, next) => prev.connection == null && next.connection != null,
          listener: (context, state) => widget.onConnected(state.connection!),
        ),
      ],
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: MatchLayout.connectFormWidth,
              child: BlocBuilder<ConnectBloc, ConnectState>(
                builder: (context, state) {
                  final connecting = state.status == ConnectStatus.connecting;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text("MutateIt", style: textTheme.displayLarge, textAlign: TextAlign.center),
                      Text(
                        "Mutation Race — out-engineer your opponent",
                        style: textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _nicknameController,
                        maxLength: 24,
                        decoration: const InputDecoration(labelText: "Nickname", border: OutlineInputBorder()),
                        onSubmitted: (_) => _connect(),
                      ),
                      const SizedBox(height: 8),
                      Text("Servers on your network", style: textTheme.labelLarge),
                      const SizedBox(height: 4),
                      if (state.discovered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Searching… or enter the host's address below",
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final server in state.discovered)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.dns_outlined),
                            title: Text(server.name),
                            subtitle: Text("${server.host}:${server.port}"),
                            onTap: () => setState(() => _addressController.text = "${server.host}:${server.port}"),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: "Server address",
                          hintText: "192.168.1.20:${Network.defaultServerPort}",
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _connect(),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: connecting ? null : _connect,
                        style: FilledButton.styleFrom(minimumSize: UiLayout.fullWidthButtonSize),
                        child: connecting
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text("Connect"),
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.error!,
                          style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
