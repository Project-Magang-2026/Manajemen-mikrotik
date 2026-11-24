import 'package:flutter/material.dart';
import '../models/router_models.dart';
import '../services/mikrotik_service.dart';
import 'winbox_dialogs.dart';

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
  final TextEditingController _searchController = TextEditingController();

  // 1-Tap Connection Ping Test State
  bool _isTestingPing = false;
  String? _pingStatusText;
  Color? _pingStatusColor;
  IconData? _pingStatusIcon;

  // Toggle reveal Wi-Fi password
  final Map<String, bool> _revealedPasswords = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runConnectionTest() async {
    setState(() {
      _isTestingPing = true;
      _pingStatusText = 'Menguji latensi ke internet...';
      _pingStatusColor = const Color(0xFF007AFF);
      _pingStatusIcon = Icons.sync_rounded;
    });

    try {
      final res = await widget.service.pingHost('8.8.8.8', count: 2);
      if (!mounted) return;

      int? latencyMs;
      bool receivedReply = false;

      for (final r in res) {
        final timeStr = r['time'] ?? '';
        if (timeStr.isNotEmpty) {
          receivedReply = true;
          // Format e.g. "15ms", "15ms20us", or "0.015s"
          final match = RegExp(r'(\d+)ms').firstMatch(timeStr);
          if (match != null) {
            latencyMs = int.tryParse(match.group(1)!);
          } else {
            final numOnly = RegExp(r'(\d+)').firstMatch(timeStr);
            if (numOnly != null) latencyMs = int.tryParse(numOnly.group(1)!);
          }
          break;
        }
      }

      setState(() {
        if (!receivedReply) {
          _pingStatusText = 'Tidak Terhubung / Tidak Ada Internet';
          _pingStatusColor = const Color(0xFFFF3B30);
          _pingStatusIcon = Icons.cloud_off_rounded;
        } else if (latencyMs != null && latencyMs < 50) {
          _pingStatusText = 'Koneksi Sangat Lancar ($latencyMs ms)';
          _pingStatusColor = const Color(0xFF34C759);
          _pingStatusIcon = Icons.check_circle_rounded;
        } else if (latencyMs != null && latencyMs < 150) {
          _pingStatusText = 'Koneksi Stabil ($latencyMs ms)';
          _pingStatusColor = const Color(0xFF007AFF);
          _pingStatusIcon = Icons.wifi_rounded;
        } else if (latencyMs != null) {
          _pingStatusText = 'Koneksi Agak Lambat ($latencyMs ms)';
          _pingStatusColor = const Color(0xFFFF9500);
          _pingStatusIcon = Icons.warning_amber_rounded;
        } else {
          _pingStatusText = 'Koneksi Terhubung Normal';
          _pingStatusColor = const Color(0xFF34C759);
          _pingStatusIcon = Icons.check_circle_rounded;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _pingStatusText = 'Gagal memeriksa koneksi';
          _pingStatusColor = const Color(0xFFFF3B30);
          _pingStatusIcon = Icons.error_outline_rounded;
        });
      }
    } finally {
      if (mounted) setState(() => _isTestingPing = false);
    }
  }

  Future<void> _handleToggleBlock(ConnectedDevice device) async {
    final willBlock = !device.isBlocked;
    final actionText = willBlock ? 'Blokir' : 'Buka Blokir';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionText Perangkat?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(
          willBlock
              ? 'Blokir akses internet untuk ${device.hostName} (${device.ipAddress} • ${device.macAddress})?'
              : 'Buka kembali akses internet untuk ${device.hostName} (${device.macAddress})?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF3C3C43)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willBlock ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.w600)),
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
      widget.showSnack(willBlock ? 'Perangkat ${device.hostName} berhasil diblokir.' : 'Blokir untuk ${device.hostName} dibuka.');
      widget.onRefresh();
    } catch (e) {
      widget.showSnack('Aksi ditolak router: ${e.toString().replaceFirst("Exception: ", "")}', isError: true);
    }
  }

  int _deviceFilterMode = 0; // 0: Semua, 1: Aktif, 2: Terblokir

  List<ConnectedDevice> get _allDevices {
    final devList = (widget.data['devices'] as List<ConnectedDevice>?) ?? [];
    if (devList.isNotEmpty) return devList;

    // Fallback dari staticDevices jika devices kosong
    final staticList = (widget.data['staticDevices'] as List<StaticHostDevice>?) ?? [];
    return staticList.map((s) => ConnectedDevice(
      macAddress: s.macAddress,
      ipAddress: s.ipAddress,
      hostName: s.customerName,
      source: s.interfaceName,
      isBlocked: s.isBlocked,
    )).toList();
  }

  List<ConnectedDevice> get _filteredDevices {
    final query = _searchQuery.trim().toLowerCase();
    var list = _allDevices;
    if (_deviceFilterMode == 1) {
      list = list.where((d) => !d.isBlocked).toList();
    } else if (_deviceFilterMode == 2) {
      list = list.where((d) => d.isBlocked).toList();
    }
    if (query.isEmpty) return list;
    return list.where((d) {
      final name = d.hostName.toLowerCase();
      final ip = d.ipAddress.toLowerCase();
      final mac = d.macAddress.toLowerCase();
      return name.contains(query) || ip.contains(query) || mac.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final resource = (widget.data['resource'] as Map<String, String>?) ?? {};
    final wifis = (widget.data['wifis'] as List<WifiInterfaceInfo>?) ?? [];
    final ips = (widget.data['ips'] as List<Map<String, String>>?) ?? [];
    final filteredDevices = _filteredDevices;
    final totalDevices = _allDevices.length;
    final blockedDevices = _allDevices.where((d) => d.isBlocked).length;

    final routerIp = ips.isNotEmpty ? (ips.first['address'] ?? widget.service.profile.host) : widget.service.profile.host;
    final boardName = resource['board-name'] ?? resource['platform'] ?? 'MikroTik Router';
    final uptime = resource['uptime'] ?? '-';
    final cpuLoad = resource['cpu-load'] ?? '0';
    final canWrite = widget.role.canWrite;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Mode Read-Only Banner jika user tidak memiliki izin write
        if (widget.role.isReadOnly)
          _buildBanner(
            title: 'Mode Baca: Akun ini tidak memiliki izin write di MikroTik. Perubahan Wi-Fi dan aksi blokir tidak aktif.',
            color: const Color(0xFFB45309),
            bg: const Color(0xFFFFF9E6),
            border: const Color(0xFFFFE082),
          ),

        // =====================================================================
        // 1. STATUS KONEKSI & TRAFIK RINGKAS
        // =====================================================================
        _buildSectionHeader('STATUS ROUTER & JARINGAN'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34C759),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Router Aktif & Terhubung',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      boardName,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF007AFF)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      icon: Icons.language_rounded,
                      label: 'IP Router',
                      value: routerIp,
                      isMonospace: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 0.5, height: 32, color: const Color(0xFFE5E5EA)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricItem(
                      icon: Icons.timer_outlined,
                      label: 'Uptime',
                      value: uptime,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 0.5, height: 32, color: const Color(0xFFE5E5EA)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricItem(
                      icon: Icons.memory_rounded,
                      label: 'CPU Load',
                      value: '$cpuLoad%',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // =====================================================================
        // 2. CEK KONEKSI CEPAT (1-TAP CONNECTION TEST)
        // =====================================================================
        _buildSectionHeader('KUALITAS KONEKSI INTERNET'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.speed_rounded, color: Color(0xFF007AFF), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tes Kecepatan Respons', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        Text('Periksa kestabilan koneksi internet ke DNS Global', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007AFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isTestingPing ? null : _runConnectionTest,
                    child: _isTestingPing
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Uji Sekarang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (_pingStatusText != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _pingStatusColor?.withValues(alpha: 0.1) ?? const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _pingStatusColor?.withValues(alpha: 0.3) ?? Colors.transparent, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Icon(_pingStatusIcon ?? Icons.info_outline_rounded, color: _pingStatusColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _pingStatusText!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _pingStatusColor ?? const Color(0xFF1C1C1E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // =====================================================================
        // 3. KONTROL WI-FI SEDERHANA (Otomatis tampil hanya jika ada interface Wi-Fi)
        // =====================================================================
        if (wifis.isNotEmpty) ...[
          _buildSectionHeader('JARINGAN WI-FI'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: wifis.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 56, color: Color(0xFFE5E5EA)),
              itemBuilder: (context, idx) {
                final w = wifis[idx];
                final isRevealed = _revealedPasswords[w.id] ?? false;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.wifi_rounded, color: Color(0xFF34C759), size: 20),
                  ),
                  title: Text(w.ssid, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Row(
                    children: [
                      Text(
                        isRevealed ? (w.password.isEmpty ? '(Terbuka/Tanpa Sandi)' : w.password) : '••••••••',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: isRevealed && w.password.isNotEmpty ? 'monospace' : null,
                          color: const Color(0xFF8E8E93),
                        ),
                      ),
                      if (w.password.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _revealedPasswords[w.id] = !isRevealed),
                          child: Icon(
                            isRevealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 15,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: canWrite ? const Color(0xFFF2F2F7) : const Color(0xFFF2F2F7),
                      foregroundColor: canWrite ? const Color(0xFF007AFF) : const Color(0xFF8E8E93),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: canWrite
                        ? () => WinboxDialogs.showEditWifiDialog(
                              context: context,
                              service: widget.service,
                              wifi: w,
                              onSuccess: widget.onRefresh,
                              showSnack: widget.showSnack,
                            )
                        : null,
                    child: Text(canWrite ? 'Ubah' : 'Lihat Saja', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // =====================================================================
        // 4. PERANGKAT TERHUBUNG & BLOKIR PERANGKAT ASING
        // =====================================================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('PERANGKAT TERHUBUNG ($totalDevices)'),
            if (blockedDevices > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '$blockedDevices diblokir',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFFF3B30)),
                ),
              ),
          ],
        ),

        // Pencarian Perangkat
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.6),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E)),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8E8E93)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF8E8E93)),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              hintText: 'Cari nama, IP, atau MAC perangkat...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(height: 8),

        // FILTER CHIPS (Semua, Aktif, Terblokir)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildDeviceFilterChip(0, 'Semua ($totalDevices)', null),
              const SizedBox(width: 6),
              _buildDeviceFilterChip(1, 'Aktif (${totalDevices - blockedDevices})', const Color(0xFF34C759)),
              const SizedBox(width: 6),
              _buildDeviceFilterChip(2, 'Diblokir ($blockedDevices)', const Color(0xFFFF3B30)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (filteredDevices.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.devices_other_rounded, size: 36, color: Color(0xFFC7C7CC)),
                  SizedBox(height: 8),
                  Text('Belum ada perangkat yang terdeteksi.', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredDevices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final d = filteredDevices[idx];
              final isBlocked = d.isBlocked;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBlocked ? const Color(0xFFFF3B30).withValues(alpha: 0.35) : const Color(0xFFE5E5EA),
                    width: isBlocked ? 1.0 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isBlocked ? const Color(0xFFFF3B30).withValues(alpha: 0.1) : const Color(0xFF007AFF).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isBlocked ? Icons.block_rounded : Icons.phonelink_rounded,
                        color: isBlocked ? const Color(0xFFFF3B30) : const Color(0xFF007AFF),
                        size: 18,
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
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1C1C1E)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isBlocked ? const Color(0xFFFF3B30).withValues(alpha: 0.1) : const Color(0xFF34C759).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isBlocked ? 'DIBLOKIR' : 'AKTIF',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isBlocked ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${d.ipAddress} • ${d.macAddress}',
                            style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Color(0xFF8E8E93)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: canWrite
                            ? (isBlocked ? const Color(0xFF34C759) : const Color(0xFFFF3B30))
                            : const Color(0xFF8E8E93),
                        side: BorderSide(
                          color: canWrite
                              ? (isBlocked ? const Color(0xFF34C759) : const Color(0xFFFF3B30))
                              : const Color(0xFFE5E5EA),
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: canWrite ? () => _handleToggleBlock(d) : null,
                      child: Text(
                        isBlocked ? 'Buka' : 'Blokir',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    bool isMonospace = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: const Color(0xFF8E8E93)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            fontFamily: isMonospace ? 'monospace' : null,
            color: const Color(0xFF1C1C1E),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDeviceFilterChip(int mode, String label, Color? accentColor) {
    final isSelected = _deviceFilterMode == mode;
    final color = accentColor ?? const Color(0xFF007AFF);

    return InkWell(
      onTap: () => setState(() => _deviceFilterMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E5EA),
            width: isSelected ? 1.0 : 0.6,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? color : const Color(0xFF6C6C70),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6C6C70),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBanner({required String title, required Color color, required Color bg, required Color border}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: color))),
        ],
      ),
    );
  }
}
