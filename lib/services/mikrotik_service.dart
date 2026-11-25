import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/router_models.dart';

class MikroTikService {
  final RouterProfile profile;
  _RouterOsBinaryClient? _persistentBinaryClient;
  Future<void> _commandQueue = Future.value();
  bool _isDisposed = false;

  final _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  bool _lastKnownConnected = true;
  bool get isConnected => _lastKnownConnected;

  void _notifyConnectionState(bool connected) {
    if (_lastKnownConnected != connected) {
      _lastKnownConnected = connected;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(connected);
      }
    }
  }

  MikroTikService(this.profile);

  /// Menutup koneksi persistent socket saat keluar atau ganti router
  Future<void> dispose() async {
    _isDisposed = true;
    await _persistentBinaryClient?.close();
    _persistentBinaryClient = null;
    if (!_connectionStateController.isClosed) {
      await _connectionStateController.close();
    }
  }

  /// Mengecek hak akses user dari /user dan /user/group di MikroTik secara serentak
  Future<UserRoleInfo> detectUserRole() async {
    final results = await Future.wait([
      _safeRunCommand('/user/print'),
      _safeRunCommand('/user/group/print'),
    ]);
    final users = results[0];
    final groups = results[1];

    final currentUser = users.firstWhere(
      (u) => u['name'] == profile.username,
      orElse: () => {'name': profile.username, 'group': 'write'},
    );

    final groupName = currentUser['group'] ?? 'read';
    final groupData = groups.firstWhere(
      (g) => g['name'] == groupName,
      orElse: () {
        final gLow = groupName.toLowerCase();
        if (gLow == 'full') return {'name': groupName, 'policy': 'full,write,read,reboot,policy,test'};
        if (gLow == 'write') return {'name': groupName, 'policy': 'write,read,reboot,test'};
        return {'name': groupName, 'policy': 'read'};
      },
    );

    final policyRaw = groupData['policy'] ?? '';
    final policies = policyRaw
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    if (policies.isEmpty) {
      final gLow = groupName.toLowerCase();
      if (gLow == 'full') {
        policies.addAll(['full', 'write', 'read', 'reboot', 'policy', 'test']);
      } else if (gLow == 'write') {
        policies.addAll(['write', 'read', 'reboot', 'test']);
      } else {
        policies.add('read');
      }
    }

    final hasFull = policies.contains('full');
    final canWrite = policies.contains('write') || hasFull;
    final canReboot = policies.contains('reboot') || hasFull;
    final canManageUsers = policies.contains('policy') || hasFull;
    final canRunTest = policies.contains('test') || hasFull;

    // Menentukan AppRole (User vs Teknisi) sesuai spesifikasi 2 Role
    final gNameLow = groupName.toLowerCase();
    AppRole role;

    if (profile.rolePreference == LoginRolePreference.user) {
      role = AppRole.user;
    } else if (gNameLow.contains('user') || gNameLow.contains('pelanggan') || gNameLow.contains('customer')) {
      role = AppRole.user;
    } else if (!canWrite) {
      // Jika akun router tidak memiliki izin write/full, amankan ke mode User (Read-Only)
      role = AppRole.user;
    } else {
      // Memiliki izin write/full dan tidak memilih mode user
      role = AppRole.technician;
    }

    return UserRoleInfo(
      username: profile.username,
      groupName: groupName,
      policies: policies,
      role: role,
      canWrite: canWrite,
      hasFull: hasFull,
      canReboot: canReboot,
      canManageUsers: canManageUsers,
      canRunTest: canRunTest,
    );
  }

  /// Pemeriksaan kilat apakah koneksi router aktif dan responsif (1:1 realtime heartbeat)
  Future<bool> checkConnection() async {
    try {
      final res = await runCommand('/system/identity/print');
      final ok = res.isNotEmpty;
      _notifyConnectionState(ok);
      return ok;
    } catch (_) {
      _notifyConnectionState(false);
      return false;
    }
  }

  /// Mengambil ringkasan data dashboard router secara serentak (Parallel Future.wait)
  Future<Map<String, dynamic>> fetchDashboardSummary() async {
    final roleFuture = detectUserRole();
    final identityFuture = _safeRunCommand('/system/identity/print');
    final resourceFuture = _safeRunCommand('/system/resource/print');
    final ipFuture = _safeRunCommand('/ip/address/print');
    final ifaceFuture = _safeRunCommand('/interface/print');
    final queuesFuture = _safeRunCommand('/queue/simple/print');
    final wifiFuture = fetchWifiInterfaces();
    final devicesFuture = fetchConnectedDevices();
    final staticDevicesFuture = fetchStaticDevices();

    final results = await Future.wait([
      roleFuture,
      identityFuture,
      resourceFuture,
      ipFuture,
      ifaceFuture,
      queuesFuture,
      wifiFuture,
      devicesFuture,
      staticDevicesFuture,
    ]);

    final role = results[0] as UserRoleInfo;
    final identityList = results[1] as List<Map<String, String>>;
    final resourceList = results[2] as List<Map<String, String>>;
    final ipList = results[3] as List<Map<String, String>>;
    final ifaceList = results[4] as List<Map<String, String>>;
    final queuesList = results[5] as List<Map<String, String>>;
    final wifiList = results[6] as List<WifiInterfaceInfo>;
    final devicesList = results[7] as List<ConnectedDevice>;
    final staticDevices = results[8] as List<StaticHostDevice>;

    return {
      'role': role,
      'identity': identityList.isNotEmpty ? (identityList.first['name'] ?? 'MikroTik') : 'MikroTik',
      'resource': resourceList.isNotEmpty ? resourceList.first : <String, String>{},
      'ips': ipList,
      'interfaces': ifaceList,
      'queues': queuesList,
      'wifis': wifiList,
      'devices': devicesList,
      'staticDevices': staticDevices,
    };
  }

  /// Membaca interface Wi-Fi (mendukung RouterOS v7 /interface/wifi & v6 /interface/wireless)
  Future<List<WifiInterfaceInfo>> fetchWifiInterfaces() async {
    final result = <WifiInterfaceInfo>[];

    // 1. Cek RouterOS v7 (/interface/wifi)
    final v7Wifis = await _safeRunCommand('/interface/wifi/print');
    if (v7Wifis.isNotEmpty) {
      for (final w in v7Wifis) {
        result.add(WifiInterfaceInfo(
          id: w['.id'] ?? '',
          name: w['name'] ?? 'wifi1',
          ssid: w['configuration.ssid'] ?? w['ssid'] ?? '(Belum diset)',
          password: w['security.passphrase'] ?? '',
          securityProfile: w['security'] ?? 'default',
          isRosV7Wifi: true,
          disabled: w['disabled'] == 'true',
        ));
      }
      return result;
    }

    // 2. Cek RouterOS v6 (/interface/wireless)
    final v6Wifis = await _safeRunCommand('/interface/wireless/print');
    final secProfiles = await _safeRunCommand('/interface/wireless/security-profiles/print');

    for (final w in v6Wifis) {
      final secName = w['security-profile'] ?? 'default';
      final matchedSec = secProfiles.firstWhere(
        (s) => s['name'] == secName,
        orElse: () => <String, String>{},
      );

      result.add(WifiInterfaceInfo(
        id: w['.id'] ?? '',
        name: w['name'] ?? 'wlan1',
        ssid: w['ssid'] ?? 'MikroTik',
        password: matchedSec['wpa2-pre-shared-key'] ?? matchedSec['wpa-pre-shared-key'] ?? '',
        securityProfile: secName,
        isRosV7Wifi: false,
        disabled: w['disabled'] == 'true',
      ));
    }

    return result;
  }

  /// Mengubah SSID dan Password Wi-Fi
  Future<void> updateWifiConfig({
    required WifiInterfaceInfo wifi,
    required String newSsid,
    required String newPassword,
  }) async {
    if (newPassword.isNotEmpty && newPassword.length < 8) {
      throw Exception('Password Wi-Fi minimal 8 karakter.');
    }

    if (wifi.isRosV7Wifi) {
      final params = <String, String>{
        '.id': wifi.id,
        'configuration.ssid': newSsid,
      };
      if (newPassword.isNotEmpty) {
        params['security.passphrase'] = newPassword;
        params['security.authentication-types'] = 'wpa2-psk,wpa3-psk';
      }
      await runCommand('/interface/wifi/set', params: params);
    } else {
      await runCommand('/interface/wireless/set', params: {
        '.id': wifi.id,
        'ssid': newSsid,
      });

      if (newPassword.isNotEmpty) {
        final secProfiles = await runCommand('/interface/wireless/security-profiles/print');
        final targetSec = secProfiles.firstWhere(
          (s) => s['name'] == wifi.securityProfile,
          orElse: () => <String, String>{},
        );
        if (targetSec['.id'] != null) {
          await runCommand('/interface/wireless/security-profiles/set', params: {
            '.id': targetSec['.id']!,
            'mode': 'dynamic-keys',
            'authentication-types': 'wpa2-psk',
            'wpa2-pre-shared-key': newPassword,
          });
        }
      }
    }
  }

  /// Mengambil daftar perangkat aktif (DHCP Lease + ARP + Wireless Registration) beserta status blokir
  Future<List<ConnectedDevice>> fetchConnectedDevices() async {
    final results = await Future.wait([
      _safeRunCommand('/ip/dhcp-server/lease/print'),
      _safeRunCommand('/ip/arp/print'),
      _safeRunCommand('/ip/firewall/filter/print'),
      _safeRunCommand('/interface/wireless/access-list/print'),
      _safeRunCommand('/interface/wifi/access-list/print'),
    ]);

    final leases = results[0];
    final arps = results[1];
    final firewallRules = results[2];
    final v6AccessList = results[3];
    final v7AccessList = results[4];

    final blockedMacs = <String>{};
    for (final rule in firewallRules) {
      final mac = (rule['src-mac-address'] ?? '').toUpperCase();
      if (mac.isNotEmpty && rule['action'] == 'drop' && rule['disabled'] != 'true') {
        blockedMacs.add(mac);
      }
    }
    for (final acl in v6AccessList) {
      final mac = (acl['mac-address'] ?? '').toUpperCase();
      if (mac.isNotEmpty && acl['authentication'] == 'no') {
        blockedMacs.add(mac);
      }
    }
    for (final acl in v7AccessList) {
      final mac = (acl['mac-address'] ?? '').toUpperCase();
      if (mac.isNotEmpty && acl['action'] == 'reject') {
        blockedMacs.add(mac);
      }
    }

    final deviceMap = <String, ConnectedDevice>{};

    for (final lease in leases) {
      final mac = (lease['mac-address'] ?? '').toUpperCase();
      if (mac.isEmpty) continue;
      deviceMap[mac] = ConnectedDevice(
        macAddress: mac,
        ipAddress: lease['address'] ?? lease['active-address'] ?? '-',
        hostName: (lease['host-name'] ?? '').isNotEmpty ? lease['host-name']! : 'Perangkat DHCP',
        source: 'DHCP Lease',
        isBlocked: blockedMacs.contains(mac),
      );
    }

    for (final arp in arps) {
      final mac = (arp['mac-address'] ?? '').toUpperCase();
      if (mac.isEmpty || deviceMap.containsKey(mac)) continue;
      deviceMap[mac] = ConnectedDevice(
        macAddress: mac,
        ipAddress: arp['address'] ?? '-',
        hostName: 'Host (${arp['interface'] ?? 'LAN'})',
        source: 'ARP Table',
        isBlocked: blockedMacs.contains(mac),
      );
    }

    // Pastikan perangkat yang diblokir tetap muncul meski sudah terputus dari ARP/DHCP
    for (final mac in blockedMacs) {
      if (!deviceMap.containsKey(mac)) {
        deviceMap[mac] = ConnectedDevice(
          macAddress: mac,
          ipAddress: 'Terblokir',
          hostName: 'Perangkat Diblokir',
          source: 'Firewall / ACL',
          isBlocked: true,
        );
      }
    }

    return deviceMap.values.toList();
  }

  /// Engine Static IP ISP: Menggabungkan data dari /ip/arp, /queue/simple, dan /ip/firewall/filter
  Future<List<StaticHostDevice>> fetchStaticDevices() async {
    final results = await Future.wait([
      _safeRunCommand('/ip/arp/print'),
      _safeRunCommand('/queue/simple/print'),
      _safeRunCommand('/ip/firewall/filter/print'),
    ]);

    final arpList = results[0];
    final queueList = results[1];
    final filterRules = results[2];

    // Filter drop rule yang diblokir oleh aplikasi ISP
    final blockedIps = <String>{};
    final blockedMacs = <String>{};
    for (final r in filterRules) {
      final action = r['action'] ?? '';
      final comment = r['comment'] ?? '';
      if (action == 'drop' && comment.startsWith('BLOCKED_BY_ISP_APP')) {
        final srcIp = (r['src-address'] ?? '').split('/')[0].trim();
        if (srcIp.isNotEmpty) blockedIps.add(srcIp);

        final srcMac = (r['src-mac-address'] ?? '').trim().toUpperCase();
        if (srcMac.isNotEmpty) blockedMacs.add(srcMac);
      }
    }

    // Index simple queue berdasarkan target IP (menghilangkan prefix /32)
    final queueByIp = <String, Map<String, String>>{};
    for (final q in queueList) {
      final target = q['target'] ?? '';
      final cleanTarget = target.split('/')[0].trim();
      if (cleanTarget.isNotEmpty) {
        queueByIp[cleanTarget] = q;
      }
    }

    final result = <StaticHostDevice>[];
    final seenIps = <String>{};
    final seenMacs = <String>{};

    // 1. Host aktif dari ARP table
    for (final arp in arpList) {
      final ip = (arp['address'] ?? '').trim();
      if (ip.isEmpty) continue;
      seenIps.add(ip);

      final mac = (arp['mac-address'] ?? '').trim().toUpperCase();
      if (mac.isNotEmpty) seenMacs.add(mac);

      final iface = arp['interface'] ?? 'ether';
      final arpComment = arp['comment'] ?? '';

      final q = queueByIp[ip];
      String customerName = '';
      String maxLimit = '-';
      String currentRate = '-';

      if (q != null) {
        final qComment = q['comment'] ?? '';
        final qName = q['name'] ?? '';
        if (qComment.isNotEmpty) {
          customerName = qComment;
        } else if (qName.isNotEmpty) {
          customerName = qName;
        }

        maxLimit = q['max-limit'] ?? '-';
        currentRate = q['rate'] ?? '-';
      }

      if (customerName.isEmpty && arpComment.isNotEmpty) {
        customerName = arpComment;
      }
      if (customerName.isEmpty) {
        customerName = 'Host $iface';
      }

      final isBlockedByIp = blockedIps.contains(ip);
      final isBlockedByMac = mac.isNotEmpty && blockedMacs.contains(mac);
      final isUnqueuedAnomaly = (q == null);

      result.add(StaticHostDevice(
        ipAddress: ip,
        macAddress: mac,
        interfaceName: iface,
        customerName: customerName,
        maxLimit: _formatRate(maxLimit),
        currentRate: _formatRate(currentRate),
        isBlockedByIp: isBlockedByIp,
        isBlockedByMac: isBlockedByMac,
        isUnqueuedAnomaly: isUnqueuedAnomaly,
        comment: arpComment.isNotEmpty ? arpComment : (q?['comment']),
      ));
    }

    // 2. IP yang terblokir namun sudah offline / hilang dari ARP
    for (final bIp in blockedIps) {
      if (!seenIps.contains(bIp)) {
        final q = queueByIp[bIp];
        final name = q?['comment']?.isNotEmpty == true
            ? q!['comment']!
            : (q?['name']?.isNotEmpty == true ? q!['name']! : 'Host Terblokir IP');
        result.add(StaticHostDevice(
          ipAddress: bIp,
          macAddress: '',
          interfaceName: 'Drop Rules',
          customerName: '$name (Offline)',
          maxLimit: _formatRate(q?['max-limit'] ?? '-'),
          currentRate: '-',
          isBlockedByIp: true,
          isBlockedByMac: false,
          isUnqueuedAnomaly: q == null,
          comment: 'Terblokir IP (Tidak ada di ARP)',
        ));
      }
    }

    // 3. MAC yang terblokir namun sudah offline / hilang dari ARP
    for (final bMac in blockedMacs) {
      if (!seenMacs.contains(bMac)) {
        result.add(StaticHostDevice(
          ipAddress: '-',
          macAddress: bMac,
          interfaceName: 'Drop Rules',
          customerName: 'Host Terblokir MAC (Offline)',
          maxLimit: '-',
          currentRate: '-',
          isBlockedByIp: false,
          isBlockedByMac: true,
          isUnqueuedAnomaly: false,
          comment: 'Terblokir MAC (Tidak ada di ARP)',
        ));
      }
    }

    return result;
  }

  static String _formatRate(String raw) {
    if (raw == '-' || raw.isEmpty) return '-';
    final parts = raw.split('/');
    if (parts.length == 2) {
      return '${_formatSingleRate(parts[0])} / ${_formatSingleRate(parts[1])}';
    }
    return _formatSingleRate(raw);
  }

  static String _formatSingleRate(String str) {
    final trimmed = str.trim();
    if (trimmed.isEmpty || trimmed == '0') return '0 bps';
    final val = int.tryParse(trimmed);
    if (val == null) return trimmed;
    if (val >= 1000000000) return '${(val / 1000000000).toStringAsFixed(1)} Gbps';
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)} Mbps';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)} Kbps';
    return '$val bps';
  }

  /// Memblokir atau membuka blokir IP Address pelanggan
  Future<void> toggleBlockIp(String ipAddress, {required bool block, String? label}) async {
    final cleanIp = ipAddress.trim();
    if (cleanIp.isEmpty || cleanIp == '-') return;

    if (block) {
      final rules = await _safeRunCommand('/ip/firewall/filter/print');
      final alreadyBlocked = rules.any((r) {
        final src = (r['src-address'] ?? '').split('/')[0].trim();
        return src == cleanIp && r['action'] == 'drop';
      });

      if (!alreadyBlocked) {
        final commentText = 'BLOCKED_BY_ISP_APP${label != null && label.trim().isNotEmpty ? ' (${label.trim()})' : ''}';
        await runCommand('/ip/firewall/filter/add', params: {
          'chain': 'forward',
          'src-address': cleanIp,
          'action': 'drop',
          'comment': commentText,
        });
      }
    } else {
      final rules = await _safeRunCommand('/ip/firewall/filter/print');
      for (final r in rules) {
        final src = (r['src-address'] ?? '').split('/')[0].trim();
        if (src == cleanIp && r['action'] == 'drop' && r['.id'] != null) {
          await runCommand('/ip/firewall/filter/remove', params: {'.id': r['.id']!});
        }
      }
    }
  }

  /// Memblokir atau membuka blokir MAC Address perangkat
  Future<void> toggleBlockMac(String macAddress, {required bool block, String? label}) async {
    final cleanMac = macAddress.trim().toUpperCase();
    if (cleanMac.isEmpty || cleanMac == '-') return;

    if (block) {
      final rules = await _safeRunCommand('/ip/firewall/filter/print');
      final alreadyBlocked = rules.any((r) {
        final src = (r['src-mac-address'] ?? '').trim().toUpperCase();
        return src == cleanMac && r['action'] == 'drop';
      });

      if (!alreadyBlocked) {
        final commentText = 'BLOCKED_BY_ISP_APP${label != null && label.trim().isNotEmpty ? ' (${label.trim()})' : ''}';
        await runCommand('/ip/firewall/filter/add', params: {
          'chain': 'forward',
          'src-mac-address': cleanMac,
          'action': 'drop',
          'comment': commentText,
        });
      }
    } else {
      // Hapus rule firewall yang memblokir MAC tersebut
      final rules = await _safeRunCommand('/ip/firewall/filter/print');
      for (final r in rules) {
        if ((r['src-mac-address'] ?? '').toUpperCase() == cleanMac && r['.id'] != null) {
          await runCommand('/ip/firewall/filter/remove', params: {'.id': r['.id']!});
        }
      }
      // Hapus juga jika ada di wireless access-list
      final v6Acl = await _safeRunCommand('/interface/wireless/access-list/print');
      for (final a in v6Acl) {
        if ((a['mac-address'] ?? '').toUpperCase() == cleanMac && a['.id'] != null) {
          await runCommand('/interface/wireless/access-list/remove', params: {'.id': a['.id']!});
        }
      }
    }
  }

  /// Fitur Teknisi: Ubah Identity Router
  Future<void> setRouterIdentity(String newName) async {
    await runCommand('/system/identity/set', params: {'name': newName});
  }

  /// Fitur Teknisi: Reboot Router
  Future<void> rebootRouter() async {
    await runCommand('/system/reboot');
  }

  /// Fitur Teknisi: Shutdown Router
  Future<void> shutdownRouter() async {
    await runCommand('/system/shutdown');
  }

  // ===================== FULL WINBOX TECHNICIAN MODULES =====================

  /// Interfaces: Toggle Enable/Disable Interface
  Future<void> toggleInterface(String id, bool enable) async {
    final cmd = enable ? '/interface/enable' : '/interface/disable';
    await runCommand(cmd, params: {'.id': id});
  }

  /// IP Address: Tambah IP Address Baru
  Future<void> addIpAddress({
    required String address,
    required String interface,
    String? comment,
  }) async {
    final params = <String, String>{
      'address': address,
      'interface': interface,
    };
    if (comment != null && comment.isNotEmpty) params['comment'] = comment;
    await runCommand('/ip/address/add', params: params);
  }

  /// IP Address: Hapus IP Address
  Future<void> removeIpAddress(String id) async {
    await runCommand('/ip/address/remove', params: {'.id': id});
  }

  /// IP Routes: Ambil Tabel Routing
  Future<List<Map<String, String>>> fetchRoutes() async {
    return await _safeRunCommand('/ip/route/print');
  }

  /// IP Routes: Tambah Static Route
  Future<void> addRoute({required String dstAddress, required String gateway}) async {
    await runCommand('/ip/route/add', params: {
      'dst-address': dstAddress,
      'gateway': gateway,
    });
  }

  /// IP Routes: Hapus Route
  Future<void> removeRoute(String id) async {
    await runCommand('/ip/route/remove', params: {'.id': id});
  }

  /// DHCP Leases: Ambil Daftar Lease
  Future<List<Map<String, String>>> fetchDhcpLeases() async {
    return await _safeRunCommand('/ip/dhcp-server/lease/print');
  }

  /// DHCP Leases: Jadikan Lease Statik (Make Static)
  Future<void> makeDhcpStatic(String id) async {
    await runCommand('/ip/dhcp-server/lease/make-static', params: {'.id': id});
  }

  /// DHCP Leases: Hapus Lease
  Future<void> removeDhcpLease(String id) async {
    await runCommand('/ip/dhcp-server/lease/remove', params: {'.id': id});
  }

  /// DNS: Ambil Pengaturan DNS
  Future<Map<String, String>> fetchDnsSettings() async {
    final list = await _safeRunCommand('/ip/dns/print');
    return list.isNotEmpty ? list.first : <String, String>{};
  }

  /// DNS: Atur Server DNS & Allow Remote Requests
  Future<void> setDnsSettings({required String servers, required bool allowRemote}) async {
    await runCommand('/ip/dns/set', params: {
      'servers': servers,
      'allow-remote-requests': allowRemote ? 'yes' : 'no',
    });
  }

  /// Firewall Filter: Ambil Rules
  Future<List<Map<String, String>>> fetchFirewallFilter() async {
    return await _safeRunCommand('/ip/firewall/filter/print');
  }

  /// Firewall NAT: Ambil NAT Rules
  Future<List<Map<String, String>>> fetchFirewallNat() async {
    return await _safeRunCommand('/ip/firewall/nat/print');
  }

  /// Firewall: Toggle Enable/Disable Rule
  Future<void> toggleRule(String tablePath, String id, bool enable) async {
    final cmd = enable ? '$tablePath/enable' : '$tablePath/disable';
    await runCommand(cmd, params: {'.id': id});
  }

  /// Firewall: Hapus Rule
  Future<void> removeRule(String tablePath, String id) async {
    await runCommand('$tablePath/remove', params: {'.id': id});
  }

  /// Simple Queues: Ambil Daftar Limit Bandwidth
  Future<List<Map<String, String>>> fetchSimpleQueues() async {
    return await _safeRunCommand('/queue/simple/print');
  }

  /// Simple Queues: Tambah Limit Bandwidth
  Future<void> addSimpleQueue({
    required String name,
    required String target,
    required String maxLimit,
  }) async {
    await runCommand('/queue/simple/add', params: {
      'name': name,
      'target': target,
      'max-limit': maxLimit,
    });
  }

  /// Simple Queues: Hapus Limit
  Future<void> removeQueue(String id) async {
    await runCommand('/queue/simple/remove', params: {'.id': id});
  }

  /// PPP / PPPoE: Ambil Daftar Secret (Pengguna ISP)
  Future<List<Map<String, String>>> fetchPppSecrets() async {
    return await _safeRunCommand('/ppp/secret/print');
  }

  /// PPP / PPPoE: Tambah Secret Baru
  Future<void> addPppSecret({
    required String name,
    required String password,
    String profile = 'default',
    String service = 'any',
  }) async {
    await runCommand('/ppp/secret/add', params: {
      'name': name,
      'password': password,
      'profile': profile,
      'service': service,
    });
  }

  /// PPP / PPPoE: Hapus Secret
  Future<void> removePppSecret(String id) async {
    await runCommand('/ppp/secret/remove', params: {'.id': id});
  }

  /// PPP / PPPoE: Ambil Daftar Sesi Aktif
  Future<List<Map<String, String>>> fetchPppActive() async {
    return await _safeRunCommand('/ppp/active/print');
  }

  /// System Logs: Ambil Catatan Event Router
  Future<List<Map<String, String>>> fetchLogs() async {
    final logs = await _safeRunCommand('/log/print');
    // Balik urutan agar log terbaru muncul di atas
    return logs.reversed.take(60).toList();
  }

  /// Diagnostic Tool: Ping Host
  Future<List<Map<String, String>>> pingHost(String target, {int count = 4}) async {
    return await runCommand(
      '/ping',
      params: {
        'address': target,
        'count': count.toString(),
      },
      timeout: Duration(seconds: count + 5),
    );
  }

  /// Generic Fetcher untuk sembarang menu RouterOS (Winbox Complete)
  Future<List<Map<String, String>>> fetchMenu(String path) async {
    return await _safeRunCommand(path);
  }

  /// Generic Executor untuk perintah / aksi RouterOS (Add, Set, Remove, Enable, Disable)
  Future<void> executePath(String path, {Map<String, String>? params}) async {
    await runCommand(path, params: params);
  }

  /// Winbox Item: Set Comment
  Future<void> setComment(String basePath, String id, String comment) async {
    await runCommand('$basePath/set', params: {'.id': id, 'comment': comment});
  }

  /// Winbox Item: Set Properties
  Future<void> setItemProperties(String basePath, String id, Map<String, String> props) async {
    final params = Map<String, String>.from(props);
    params['.id'] = id;
    await runCommand('$basePath/set', params: params);
  }

  /// Winbox: Undo Action
  Future<void> undo() async {
    await _safeRunCommand('/undo');
  }

  /// Winbox: Redo Action
  Future<void> redo() async {
    await _safeRunCommand('/redo');
  }

  /// Winbox: Buat File Backup Router
  Future<void> createBackup(String name) async {
    await runCommand(
      '/system/backup/save',
      params: {'name': name},
      timeout: const Duration(seconds: 10),
    );
  }

  /// Menjalankan perintah RouterOS secara aman (mengembalikan list kosong jika menu tidak ada di perangkat)
  Future<List<Map<String, String>>> _safeRunCommand(String path) async {
    try {
      return await runCommand(path);
    } catch (_) {
      return [];
    }
  }

  /// Eksekutor antrean perintah FIFO persisten untuk Binary API (8728) dan REST API (80/443)
  Future<List<Map<String, String>>> runCommand(
    String path, {
    Map<String, String>? params,
    Duration? timeout,
  }) {
    if (_isDisposed) {
      return Future.error(Exception('MikroTikService sudah di-dispose.'));
    }

    final completer = Completer<List<Map<String, String>>>();
    _commandQueue = _commandQueue.then((_) async {
      try {
        final result = await _executeCommand(path, params: params, timeout: timeout);
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<List<Map<String, String>>> _executeCommand(
    String path, {
    Map<String, String>? params,
    Duration? timeout,
  }) async {
    if (profile.protocol == ApiProtocol.routerOsApi8728) {
      if (_persistentBinaryClient == null || _persistentBinaryClient!.isClosed) {
        final client = _RouterOsBinaryClient(
          profile.host,
          profile.port,
          onConnectionChanged: _notifyConnectionState,
        );
        await client.connectAndLogin(profile.username, profile.password);
        _persistentBinaryClient = client;
        _notifyConnectionState(true);
      }

      try {
        final words = <String>[path];
        if (params != null) {
          params.forEach((k, v) => words.add('=$k=$v'));
        }
        final res = await _persistentBinaryClient!.sendCommand(
          words,
          timeout: timeout ?? const Duration(milliseconds: 2500),
        );
        _notifyConnectionState(true);
        return res;
      } catch (e) {
        // Socket terputus atau timeout, tutup client agar perintah berikutnya melakukan auto-reconnect
        _notifyConnectionState(false);
        await _persistentBinaryClient?.close();
        _persistentBinaryClient = null;
        rethrow;
      }
    } else {
      final scheme = profile.protocol == ApiProtocol.restApiHttps ? 'https' : 'http';
      final cleanPath = path.startsWith('/') ? path : '/$path';
      final url = '$scheme://${profile.host}:${profile.port}/rest$cleanPath';

      final httpClient = HttpClient()
        ..connectionTimeout = const Duration(milliseconds: 1500)
        ..badCertificateCallback = (cert, host, port) => true;

      try {
        final isPrint = cleanPath.endsWith('/print');
        final method = isPrint ? 'GET' : 'POST';
        final targetUrl = isPrint ? url.replaceFirst(RegExp(r'/print$'), '') : url;

        final request = await httpClient.openUrl(method, Uri.parse(targetUrl));
        final auth = base64Encode(utf8.encode('${profile.username}:${profile.password}'));
        request.headers.set(HttpHeaders.authorizationHeader, 'Basic $auth');
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

        if (!isPrint && params != null && params.isNotEmpty) {
          request.write(jsonEncode(params));
        }

        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode == 401) {
          _notifyConnectionState(false);
          throw Exception('Username atau password salah (401).');
        }
        if (response.statusCode >= 400) {
          throw Exception('HTTP ${response.statusCode}: $body');
        }
        _notifyConnectionState(true);
        if (body.isEmpty) return [];

        final decoded = jsonDecode(body);
        if (decoded is List) {
          return decoded
              .map((item) => Map<String, String>.from(
                    (item as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
                  ))
              .toList();
        } else if (decoded is Map) {
          return [
            decoded.map((k, v) => MapEntry(k.toString(), v.toString())),
          ];
        }
        return [];
      } catch (e) {
        _notifyConnectionState(false);
        rethrow;
      } finally {
        httpClient.close();
      }
    }
  }
}

/// Client socket biner MikroTik RouterOS API (Port 8728)
class _RouterOsBinaryClient {
  final String host;
  final int port;
  final void Function(bool isConnected)? onConnectionChanged;
  Socket? _socket;
  final List<int> _buffer = [];
  final List<String> _currentSentence = [];
  final StreamController<List<String>> _controller = StreamController.broadcast();
  bool _isClosed = false;

  bool get isClosed => _isClosed;

  _RouterOsBinaryClient(this.host, this.port, {this.onConnectionChanged});

  Future<void> connectAndLogin(String username, String password) async {
    _isClosed = false;
    _socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 1500));
    _socket!.setOption(SocketOption.tcpNoDelay, true);
    onConnectionChanged?.call(true);

    _socket!.listen(
      _onData,
      onError: (e) {
        _isClosed = true;
        onConnectionChanged?.call(false);
        if (!_controller.isClosed) _controller.addError(e);
      },
      onDone: () {
        _isClosed = true;
        onConnectionChanged?.call(false);
        if (!_controller.isClosed) _controller.close();
      },
      cancelOnError: false,
    );

    await sendCommand(['/login', '=name=$username', '=password=$password']);
  }

  void _onData(List<int> data) {
    _buffer.addAll(data);
    while (true) {
      final word = _decodeNextWord();
      if (word == null) break;
      if (word.isEmpty) {
        _controller.add(List<String>.from(_currentSentence));
        _currentSentence.clear();
      } else {
        _currentSentence.add(word);
      }
    }
  }

  String? _decodeNextWord() {
    if (_buffer.isEmpty) return null;
    final b0 = _buffer[0];
    int len = 0;
    int offset = 0;

    if ((b0 & 0x80) == 0x00) {
      len = b0;
      offset = 1;
    } else if ((b0 & 0xC0) == 0x80) {
      if (_buffer.length < 2) return null;
      len = ((b0 & 0x3F) << 8) | _buffer[1];
      offset = 2;
    } else if ((b0 & 0xE0) == 0xC0) {
      if (_buffer.length < 3) return null;
      len = ((b0 & 0x1F) << 16) | (_buffer[1] << 8) | _buffer[2];
      offset = 3;
    } else if ((b0 & 0xF0) == 0xE0) {
      if (_buffer.length < 4) return null;
      len = ((b0 & 0x0F) << 24) | (_buffer[1] << 16) | (_buffer[2] << 8) | _buffer[3];
      offset = 4;
    } else {
      if (_buffer.length < 5) return null;
      len = (_buffer[1] << 24) | (_buffer[2] << 16) | (_buffer[3] << 8) | _buffer[4];
      offset = 5;
    }

    if (_buffer.length < offset + len) return null;
    final bytes = _buffer.sublist(offset, offset + len);
    _buffer.removeRange(0, offset + len);
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<List<Map<String, String>>> sendCommand(
    List<String> words, {
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    if (_socket == null) throw Exception('Socket belum terhubung.');
    final completer = Completer<List<Map<String, String>>>();
    final records = <Map<String, String>>[];
    String? trapError;

    late StreamSubscription<List<String>> sub;
    sub = _controller.stream.listen(
      (sentence) {
        if (sentence.isEmpty) return;
        final tag = sentence.first;
        if (tag == '!re') {
          final row = <String, String>{};
          for (final w in sentence.skip(1)) {
            if (w.startsWith('=')) {
              final idx = w.indexOf('=', 1);
              if (idx != -1) row[w.substring(1, idx)] = w.substring(idx + 1);
            }
          }
          records.add(row);
        } else if (tag == '!trap') {
          for (final w in sentence.skip(1)) {
            if (w.startsWith('=message=')) {
              trapError = w.substring('=message='.length);
            }
          }
        } else if (tag == '!done') {
          sub.cancel();
          if (trapError != null) {
            completer.completeError(Exception(trapError));
          } else {
            completer.complete(records);
          }
        } else if (tag == '!fatal') {
          sub.cancel();
          completer.completeError(Exception('Koneksi diputus router (!fatal).'));
        }
      },
      onError: (e) {
        sub.cancel();
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    for (final w in words) {
      final bytes = utf8.encode(w);
      _socket!.add(_encodeLength(bytes.length));
      _socket!.add(bytes);
    }
    _socket!.add([0x00]);
    await _socket!.flush();

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        sub.cancel();
        _isClosed = true;
        onConnectionChanged?.call(false);
        throw TimeoutException('Timeout menunggu respons router.');
      },
    );
  }

  List<int> _encodeLength(int len) {
    if (len < 0x80) return [len];
    if (len < 0x4000) return [(len >> 8) | 0x80, len & 0xFF];
    if (len < 0x200000) return [(len >> 16) | 0xC0, (len >> 8) & 0xFF, len & 0xFF];
    if (len < 0x10000000) {
      return [(len >> 24) | 0xE0, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF];
    }
    return [0xF0, (len >> 24) & 0xFF, (len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF];
  }

  Future<void> close() async {
    _isClosed = true;
    onConnectionChanged?.call(false);
    try {
      await _socket?.close();
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    if (!_controller.isClosed) await _controller.close();
  }
}