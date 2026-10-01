import "dart:async";
import "dart:convert";
import "dart:io";
import "../../constants.dart";
import "discovered_server.dart";

/// Listens for the backend's UDP beacon. Discovery is best effort: if the socket can't be
/// bound (e.g. blocked by the OS) the stream just stays empty and the user types the address.
class LanDiscovery {
  bool get isSupported => true;

  Stream<DiscoveredServer> discover() {
    RawDatagramSocket? socket;
    late final StreamController<DiscoveredServer> controller;

    Future<void> start() async {
      try {
        socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          Network.discoveryPort,
          // Lets two app instances on one machine both listen (e.g. for local testing).
          reuseAddress: true,
          reusePort: !Platform.isWindows,
        );
      } on SocketException {
        return;
      }
      socket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket?.receive();
        if (datagram == null) return;
        final server = _parse(datagram);
        if (server != null && !controller.isClosed) controller.add(server);
      });
    }

    controller = StreamController<DiscoveredServer>(onListen: start, onCancel: () => socket?.close());
    return controller.stream;
  }

  DiscoveredServer? _parse(Datagram datagram) {
    try {
      final json = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (json["service"] != Network.discoveryServiceName) return null;
      return DiscoveredServer(
        name: json["name"] as String? ?? datagram.address.address,
        host: datagram.address.address,
        port: json["port"] as int,
      );
    } catch (_) {
      return null;
    }
  }
}
