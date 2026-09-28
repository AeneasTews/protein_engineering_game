import "discovered_server.dart";

/// Browsers can't open UDP sockets, so on the web no servers are discovered.
class LanDiscovery {
  Stream<DiscoveredServer> discover() => const Stream.empty();
}
