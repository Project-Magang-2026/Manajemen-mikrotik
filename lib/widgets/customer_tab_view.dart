import 'package:flutter/material.dart';
import '../models/router_models.dart';
import '../services/mikrotik_service.dart';

class CustomerTabView extends StatefulWidget {
  final Map<String, dynamic> data;
  final UserRoleInfo role;
  final MikroTikService service;
  final VoidCallback onRefresh;
  final Function(String, {bool isError}) showSnack;

  const CustomerTabView({
    super.key,
    required this.data,
    required this.role,
    required this.service,
    required this.onRefresh,
    required this.showSnack,
  });

  @override
  State<CustomerTabView> createState() => _CustomerTabViewState();
}

class _CustomerTabViewState extends State<CustomerTabView> {
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isTestingPing = false;
  String? _pingStatus;
  Color? _pingColor;
  IconData? _pingIcon;
  final Map<String, bool> _revealedPasswords = {};
  int _deviceFilterMode = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runPingTest() async {
    setState(() {
      _isTestingPing = true;
      _pingStatus = 'Menguji koneksi...';
      _pingColor = const Color(0xFF0071E3);
      _pingIcon = Icons.sync_rounded;
    });
    try {
      final res = await widget.service.pingHost('8.8.8.8', count: 2);
      if (!mounted) return;
      int? latency;
      bool received = false;
      for (final r in res) {
        final timeStr = r['time'] ?? '';
        if (timeStr.isNotEmpty) {
          received = true;
          final match = RegExp(r'(\d+)ms').firstMatch(timeStr);
          if (match != null) latency = int.tryParse(match.group(1)!);
          break;
        }
      }
      setState(() {
        if (!received) {
          _pingStatus = 'Tidak ada internet';
          _pingColor = const Color(0xFFFF3B30);
          _pingIcon = Icons.cloud_off_rounded;
        } else if (latency != null && latency < 50) {
          _pingStatus = 'Sangat Lancar ($latency ms)';
          _pingColor = const Color(0xFF34C759);
          _pingIcon = Icons.check_circle_rounded;
        } else if (latency != null && latency < 150) {
          _pingStatus = 'Stabil ($latency ms)';
          _pingColor = const Color(0xFF0071E3);
          _pingIcon = Icons.wifi_rounded;
        } else {
          _pingStatus = 'Agak Lambat ($latency ms)';
          _pingColor = const Color(0xFFFF9500);
          _pingIcon = Icons.warning_amber_rounded;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _pingStatus = 'Gagal tes koneksi';
          _pingColor = const Color(0xFFFF3B30);
          _pingIcon = Icons.error_outline_rounded;
        });
      }
    } finally {
      if (mounted) setState(() => _isTestingPing = false);
    }
  }

  List<ConnectedDevice> get _allDevices {
    final devList = (widget.data['devices'] as List<ConnectedDevice>?) ?? [];
    if (devList.isNotEmpty) return devList;
    final staticList = (widget.data['staticDevices'] as List<StaticHostDevice>?) ?? [];
    return staticList
        .map((s) => ConnectedDevice(
              macAddress: s.macAddress,
              ipAddress: s.ipAddress,
              hostName: s.customerName,
              source: s.interfaceName,
              isBlocked: s.isBlocked,
            ))
        .toList();
  }

  List<ConnectedDevice> get _filteredDevices {
    var list = _allDevices;
    if (_deviceFilterMode == 1) list = list.where((d) => !d.isBlocked).toList();
    if (_deviceFilterMode == 2) list = list.where((d) => d.isBlocked).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((d) {
        return d.hostName.toLowerCase().contains(q) ||
            d.ipAddress.toLowerCase().contains(q) ||
            d.macAddress.toLowerCase().contains(q);
      }).toList();
    }
    return list;
  }

  Future<void> _toggleBlock(ConnectedDevice device) async {
    final willBlock = !device.isBlocked;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(willBlock ? 'Blokir Perangkat?' : 'Buka Blokir?'),
        content: Text(
          willBlock
              ? 'Blokir ${device.hostName} (${device.macAddress})?'
              : 'Buka blokir ${device.hostName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: willBlock ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willBlock ? 'Blokir' : 'Buka'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.service.toggleBlockMac(device.macAddress, block: willBlock, label: device.hostName);
      if (device.ipAddress.isNotEmpty && device.ipAddress != '-' && device.ipAddress != 'Terblokir') {
        await widget.service.toggleBlockIp(device.ipAddress, block: willBlock, label: device.hostName);
      }
      widget.showSnack(willBlock ? 'Diblokir.' : 'Blokir dibuka.');
      widget.onRefresh();
    } catch (e) {
      widget.showSnack('Gagal: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resource = (widget.data['resource'] as Map<String, String>?) ?? {};
    final wifis = (widget.data['wifis'] as List<WifiInterfaceInfo>?) ?? [];
    final ips = (widget.data['ips'] as List<Map<String, String>>?) ?? [];
    final devices = _filteredDevices;
    final totalDevices = _allDevices.length;
    final blockedCount = _allDevices.where((d) => d.isBlocked).length;
    final routerIp = ips.isNotEmpty ? (ips.first['address'] ?? '') : '';
    final uptime = resource['uptime'] ?? '-';
    final cpuLoad = resource['cpu-load'] ?? '0';
    final canWrite = widget.role.canWrite;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Read-only notice
        if (widget.role.isReadOnly) ...[
          _buildNotice(
            'Mode Baca: Akun tidak memiliki izin write.',
            Icons.info_outline_rounded,
            const Color(0xFFFF9500),
          ),
          const SizedBox(height: 12),
        ],

        // Router Status Card
        _buildStatusCard(routerIp, uptime, cpuLoad, resource),
        const SizedBox(height: 16),

        // Ping Test
        _buildPingTestCard(),
        const SizedBox(height: 16),

        // WiFi Section
        if (wifis.isNotEmpty) ...[
          _buildSectionLabel('WI-FI'),
          const SizedBox(height: 8),
          _buildWifiCard(wifis, canWrite),
          const SizedBox(height: 16),
        ],

        // Devices Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionLabel('PERANGKAT ($totalDevices)'),
            if (blockedCount > 0)
              Text(
                '$blockedCount diblokir',
                style: const TextStyle(fontSize: 11, color: Color(0xFFFF3B30), fontWeight: FontWeight.w600),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Search
        TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Cari perangkat...',
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFFAEAEB2)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            isDense: true,
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 8),

        // Filter chips
        Row(
          children: [
            _buildFilterChip(0, 'Semua'),
            const SizedBox(width: 6),
            _buildFilterChip(1, 'Aktif'),
            const SizedBox(width: 6),
            _buildFilterChip(2, 'Blokir'),
          ],
        ),
        const SizedBox(height: 12),

        // Device list
        if (devices.isEmpty)
          _buildEmptyState()
        else
          ...devices.map((d) => _buildDeviceCard(d, canWrite)),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF86868B), letterSpacing: 0.8),
    );
  }

  Widget _buildNotice(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String routerIp, String uptime, String cpuLoad, Map<String, String> resource) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8ED)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text('Router Aktif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0071E3).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  resource['board-name'] ?? 'MikroTik',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0071E3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildMetric('IP Router', routerIp, Icons.language_rounded)),
              Expanded(child: _buildMetric('Uptime', uptime, Icons.timer_outlined)),
              Expanded(child: _buildMetric('CPU', '$cpuLoad%', Icons.memory_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFFAEAEB2)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF86868B))),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPingTestCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8ED)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF0071E3).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.speed_rounded, size: 18, color: Color(0xFF0071E3)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tes Koneksi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    SizedBox(height: 2),
                    Text('Ping ke DNS Global', style: TextStyle(fontSize: 11, color: Color(0xFF86868B))),
                  ],
                ),
              ),
              SizedBox(
                height: 32,
                child: FilledButton(
                  onPressed: _isTestingPing ? null : _runPingTest,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0071E3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: _isTestingPing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Uji', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          if (_pingStatus != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _pingColor?.withOpacity(0.08) ?? const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_pingIcon ?? Icons.info_outline, color: _pingColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pingStatus!,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _pingColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWifiCard(List<WifiInterfaceInfo> wifis, bool canWrite) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8ED)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < wifis.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wifi_rounded, size: 18, color: Color(0xFF34C759)),
              ),
              title: Text(wifis[i].ssid, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Row(
                children: [
                  Text(
                    _revealedPasswords[wifis[i].id] == true
                        ? (wifis[i].password.isEmpty ? '(Open)' : wifis[i].password)
                        : '••••••••',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF86868B)),
                  ),
                  if (wifis[i].password.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() {
                        _revealedPasswords[wifis[i].id] = !(_revealedPasswords[wifis[i].id] ?? false);
                      }),
                      child: Icon(
                        _revealedPasswords[wifis[i].id] == true
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 14,
                        color: const Color(0xFFAEAEB2),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: canWrite
                  ? TextButton(
                      onPressed: () => _showEditWifiDialog(wifis[i]),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0071E3),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      child: const Text('Ubah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(int mode, String label) {
    final selected = _deviceFilterMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _deviceFilterMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0071E3).withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF0071E3) : const Color(0xFFE8E8ED),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? const Color(0xFF0071E3) : const Color(0xFF86868B),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard(ConnectedDevice d, bool canWrite) {
    final blocked = d.isBlocked;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: blocked ? const Color(0xFFFF3B30).withOpacity(0.4) : const Color(0xFFE8E8ED),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: blocked
                  ? const Color(0xFFFF3B30).withOpacity(0.08)
                  : const Color(0xFF0071E3).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              blocked ? Icons.block_rounded : Icons.phonelink_rounded,
              size: 16,
              color: blocked ? const Color(0xFFFF3B30) : const Color(0xFF0071E3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.hostName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: blocked
                            ? const Color(0xFFFF3B30).withOpacity(0.1)
                            : const Color(0xFF34C759).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        blocked ? 'BLOKIR' : 'AKTIF',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: blocked ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${d.ipAddress} • ${d.macAddress}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF86868B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (canWrite)
            SizedBox(
              height: 30,
              child: OutlinedButton(
                onPressed: () => _toggleBlock(d),
                style: OutlinedButton.styleFrom(
                  foregroundColor: blocked ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                  side: BorderSide(
                    color: blocked ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(
                  blocked ? 'Buka' : 'Blokir',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8ED)),
      ),
      child: const Column(
        children: [
          Icon(Icons.devices_other_rounded, size: 32, color: Color(0xFFD1D1D6)),
          SizedBox(height: 8),
          Text('Belum ada perangkat terdeteksi', style: TextStyle(color: Color(0xFF86868B), fontSize: 13)),
        ],
      ),
    );
  }

  void _showEditWifiDialog(WifiInterfaceInfo wifi) {
    final ssidCtrl = TextEditingController(text: wifi.ssid);
    final passCtrl = TextEditingController(text: wifi.password);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Atur Wi-Fi (${wifi.name})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nama Wi-Fi (SSID)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6C6C70))),
            const SizedBox(height: 6),
            TextField(
              controller: ssidCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Password Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6C6C70))),
            const SizedBox(height: 6),
            TextField(
              controller: passCtrl,
              decoration: InputDecoration(
                hintText: 'Min. 8 karakter',
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final newSsid = ssidCtrl.text.trim();
              final newPass = passCtrl.text;
              if (newSsid.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await widget.service.updateWifiConfig(
                  wifi: wifi,
                  newSsid: newSsid,
                  newPassword: newPass,
                );
                widget.showSnack('Pengaturan Wi-Fi berhasil diperbarui!');
                widget.onRefresh();
              } catch (e) {
                widget.showSnack('Gagal: $e', isError: true);
              }
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0071E3))),
          ),
        ],
      ),
    );
  }
}