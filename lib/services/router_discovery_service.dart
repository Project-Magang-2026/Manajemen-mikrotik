import 'dart:async';
import 'dart:io';

class DiscoveredRouter {
  final String ip;
  final int port;
  final String label;

  DiscoveredRouter({
    required this.ip,
    required this.port,
    required this.label,
  });
}

class RouterDiscoveryService {
  // Port umum MikroTik: 8728 (API Binary), 80 (HTTP REST), 443 (HTTPS REST), 8729 (API SSL)
  static const List<int> _portsToProbe = [8728, 80, 443, 8729];

  /// Pindai jaringan lokal Wi-Fi untuk menemukan router MikroTik aktif
  Future<DiscoveredRouter?> discoverActiveRouter({
    Duration probeTimeout = const Duration(milliseconds: 900),
  }) async {
    final candidateIps = await _getCandidateIps();

    // Pindai kandidat gateway secara paralel
    final futures = candidateIps.map((ip) => _probeHost(ip, probeTimeout)).toList();
    final results = await Future.wait(futures);

    // Prioritaskan port 8728 (Native Binary API) jika ada beberapa port terbuka
    DiscoveredRouter? bestResult;
    for (final r in results) {
      if (r != null) {
        if (r.port == 8728) return r;
        bestResult ??= r;
      }
    }

    return bestResult;
  }

  Future<List<String>> _getCandidateIps() async {
    final candidates = <String>{};

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip == '127.0.0.1' || ip.startsWith('169.254.')) continue;

          final parts = ip.split('.');
          if (parts.length == 4) {
            final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
            // Default gateway router pada umumnya (.1 atau .254)
            candidates.add('$prefix.1');
            candidates.add('$prefix.254');
          }
        }
      }
    } catch (_) {}

    // IP Default bawaan pabrik MikroTik
    candidates.add('192.168.88.1');
    candidates.add('192.168.1.1');
    candidates.add('10.0.0.1');

    return candidates.toList();
  }

  Future<DiscoveredRouter?> _probeHost(String host, Duration timeout) async {
    for (final port in _portsToProbe) {
      try {
        final socket = await Socket.connect(host, port, timeout: timeout);
        await socket.close();
        return DiscoveredRouter(
          ip: host,
          port: port,
          label: 'Router ($host)',
        );
      } catch (_) {
        // Port tidak merespons, coba port berikutnya
      }
    }
    return null;
  }
}
