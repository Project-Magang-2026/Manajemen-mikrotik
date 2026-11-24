import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Hasil deteksi router MikroTik pada jaringan lokal
class MikrotikDiscoveryResult {
  /// Alamat IP Gateway / Router MikroTik (misal: 192.168.88.1 atau 192.168.1.1)
  final String gatewayIp;

  /// Port API terdeteksi yang siap digunakan untuk koneksi (prioritas: 8728 -> 8777 -> 80)
  final int apiPort;

  /// Daftar port signature MikroTik yang terbuka
  final List<int> openPorts;

  /// Indikator apakah port Winbox (8291) terbuka
  final bool hasWinbox;

  /// Nama SSID Wi-Fi aktif (jika diizinkan sistem)
  final String? wifiSsid;

  const MikrotikDiscoveryResult({
    required this.gatewayIp,
    required this.apiPort,
    required this.openPorts,
    required this.hasWinbox,
    this.wifiSsid,
  });

  @override
  String toString() =>
      'MikrotikDiscoveryResult(gateway: $gatewayIp, apiPort: $apiPort, openPorts: $openPorts, winbox: $hasWinbox, ssid: $wifiSsid)';
}

/// Zero-Touch Auto-Discovery Engine untuk MikroTik Router
class MikrotikAutoDiscovery {
  final NetworkInfo _networkInfo;

  MikrotikAutoDiscovery({NetworkInfo? networkInfo})
      : _networkInfo = networkInfo ?? NetworkInfo();

  /// Port signature MikroTik untuk validasi keberadaan router:
  /// - 8291: Winbox / MAC-Telnet (Indikator terkuat perangkat MikroTik)
  /// - 8728: RouterOS API biner standar
  /// - 8777: Port API alternatif umum yang sering disetel oleh ISP
  /// - 80: WebFig HTTP (Web interface RouterOS)
  static const int portWinbox = 8291;
  static const int portApiDefault = 8728;
  static const int portApiCustom = 8777;
  static const int portWebFig = 80;

  static const List<int> probePorts = [
    portWinbox,
    portApiDefault,
    portApiCustom,
    portWebFig,
  ];

  /// Menjalankan pemindaian Zero-Touch di latar belakang.
  /// Mengembalikan [MikrotikDiscoveryResult] jika router MikroTik terdeteksi,
  /// atau `null` jika tidak terhubung Wi-Fi, port tertutup, atau terjadi kegagalan.
  Future<MikrotikDiscoveryResult?> discoverGatewayRouter({
    Duration timeoutPerPort = const Duration(seconds: 2),
  }) async {
    try {
      // 1. Dapatkan IP Gateway Wi-Fi
      final gatewayIp = await _resolveGatewayIp();
      if (gatewayIp == null || gatewayIp.isEmpty || gatewayIp == '0.0.0.0') {
        return null;
      }

      // Ambil SSID Wi-Fi opsional
      String? ssid;
      try {
        ssid = await _networkInfo.getWifiName();
        if (ssid != null) {
          // Bersihkan tanda petik ganda yang sering disertakan oleh iOS/Android
          ssid = ssid.replaceAll('"', '').trim();
          if (ssid.isEmpty) ssid = null;
        }
      } catch (_) {}

      // 2. Lakukan probe TCP port signature secara paralel dan non-blocking
      final portFutures = probePorts.map((port) => _probePort(gatewayIp, port, timeoutPerPort));
      final probeResults = await Future.wait(portFutures);

      final openPorts = <int>[];
      for (final res in probeResults) {
        if (res.isOpen) {
          openPorts.add(res.port);
        }
      }

      final hasWinbox = openPorts.contains(portWinbox);
      final hasApiDefault = openPorts.contains(portApiDefault);
      final hasApiCustom = openPorts.contains(portApiCustom);

      // 3. Evaluasi Signature MikroTik:
      // Harus memiliki Port 8291 (Winbox) ATAU salah satu port API (8728 / 8777)
      if (hasWinbox || hasApiDefault || hasApiCustom) {
        // Tentukan port API terbaik untuk form login
        final chosenApiPort = hasApiDefault
            ? portApiDefault
            : (hasApiCustom ? portApiCustom : (openPorts.contains(portWebFig) ? portWebFig : portApiDefault));

        return MikrotikDiscoveryResult(
          gatewayIp: gatewayIp,
          apiPort: chosenApiPort,
          openPorts: openPorts,
          hasWinbox: hasWinbox,
          wifiSsid: ssid,
        );
      }

      return null;
    } catch (_) {
      // Silent fail tanpa mengganggu pengguna
      return null;
    }
  }

  /// Meminta izin lokasi di Android (diperlukan untuk membaca info Wi-Fi pada Android 10+)
  Future<bool> _requestLocationPermissionIfNeeded() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.locationWhenInUse.status;
        if (!status.isGranted) {
          status = await Permission.locationWhenInUse.request();
        }
        return status.isGranted;
      }
    } catch (_) {}
    return true;
  }

  /// Menyelesaikan IP Gateway melalui network_info_plus dengan fallback ke NetworkInterface lokal
  Future<String?> _resolveGatewayIp() async {
    // Coba minta izin lokasi terlebih dahulu jika di Android
    await _requestLocationPermissionIfNeeded();

    String? gateway;
    try {
      gateway = await _networkInfo.getWifiGatewayIP();
      if (gateway != null && gateway.trim().isNotEmpty && gateway != '0.0.0.0') {
        return gateway.trim();
      }
    } catch (_) {}

    // Fallback: Analisis alamat IP interface lokal jika network_info_plus gagal mendapatkan gateway
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final iface in interfaces) {
        final nameLower = iface.name.toLowerCase();
        // Hanya cek interface yang berasosiasi dengan Wi-Fi / WLAN
        if (nameLower.contains('wlan') || nameLower.contains('wi-fi') || nameLower.contains('en0')) {
          for (final addr in iface.addresses) {
            final ip = addr.address;
            if (ip == '127.0.0.1' || ip.startsWith('169.254.')) continue;
            final parts = ip.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}.1';
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Probe satu port TCP dengan batas timeout ketat (2 detik).
  /// Menangani SocketException dan TimeoutException secara aman.
  Future<_PortProbeResult> _probePort(String host, int port, Duration timeout) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return _PortProbeResult(port: port, isOpen: true);
    } catch (_) {
      return _PortProbeResult(port: port, isOpen: false);
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }
}

class _PortProbeResult {
  final int port;
  final bool isOpen;
  const _PortProbeResult({required this.port, required this.isOpen});
}
