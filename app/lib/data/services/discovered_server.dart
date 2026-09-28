import "package:equatable/equatable.dart";

class DiscoveredServer extends Equatable {
  final String name;
  final String host;
  final int port;

  const DiscoveredServer({required this.name, required this.host, required this.port});

  String get baseUrl => "http://$host:$port";

  @override
  List<Object?> get props => [name, host, port];
}
