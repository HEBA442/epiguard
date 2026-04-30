import 'package:multicast_dns/multicast_dns.dart';
import 'api_endpoints.dart';

/// Discovers the EpiGuard Flask server on the local network via mDNS.
/// The Flask server broadcasts itself as `_epiguard._tcp.local.`
class ServerDiscovery {
  static const String _serviceType = '_epiguard._tcp';

  /// Scans the local network for the EpiGuard server.
  /// Sets [ApiEndpoints.baseUrl] if found.
  /// Times out after [timeout] and keeps the fallback URL if nothing is found.
  static Future<bool> findServer({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final MDnsClient client = MDnsClient();
      await client.start();

      await for (final PtrResourceRecord ptr in client
          .lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(_serviceType),
          )
          .timeout(timeout, onTimeout: (_) => _.close())) {
        // Resolve the IP address from the PTR record
        await for (final IPAddressResourceRecord ip in client
            .lookup<IPAddressResourceRecord>(
              ResourceRecordQuery.addressIPv4(ptr.domainName),
            )
            .timeout(const Duration(seconds: 2), onTimeout: (_) => _.close())) {
          final discovered = 'http://${ip.address.address}:5000';
          ApiEndpoints.baseUrl = discovered;
          client.stop();
          return true;
        }
      }

      client.stop();
      return false; // Not found — fallback URL stays in place

    } catch (_) {
      return false;
    }
  }
}
