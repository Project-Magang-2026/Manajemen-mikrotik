import 'dart:async';
import 'package:flutter/material.dart';
import '../models/router_models.dart';
import '../services/mikrotik_service.dart';
import '../services/profile_storage_service.dart';
import '../widgets/customer_tab_view.dart';
import '../widgets/winbox_panel_view.dart';
import 'profile_list_screen.dart';

class RouterDashboardScreen extends StatefulWidget {
  final RouterProfile profile;
  final Map<String, dynamic> initialData;

  const RouterDashboardScreen({
    super.key,
    required this.profile,
    required this.initialData,
  });

  @override
  State<RouterDashboardScreen> createState() => _RouterDashboardScreenState();
}

class _RouterDashboardScreenState extends State<RouterDashboardScreen> {
  late MikroTikService _service;
  late Map<String, dynamic> _data;
  bool _isLoading = false;
  int _selectedTab = 0; // 0: Pelanggan, 1: Winbox PC

  bool _isOnline = true;
  Timer? _liveHeartbeatTimer;

  @override
  void initState() {
    super.initState();
    _service = MikroTikService(widget.profile);
    _data = widget.initialData;
    _startLiveHeartbeat();
  }

  @override
  void dispose() {
    _liveHeartbeatTimer?.cancel();
    _service.dispose();
    super.dispose();
  }

  void _startLiveHeartbeat() {
    _liveHeartbeatTimer?.cancel();
    _liveHeartbeatTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (!mounted || _isLoading) return;
      final isAlive = await _service.checkConnection();
      if (!mounted) return;

      if (isAlive != _isOnline) {
        setState(() {
          _isOnline = isAlive;
          if (isAlive) {
            _showSnack('Koneksi router kembali aktif (Online).');
          }
        });
      }

      // Update ringan status resource (CPU, Uptime) di background tanpa loading spinner
      if (isAlive) {
        try {
          final res = await _service.fetchMenu('/system/resource/print');
          if (mounted && res.isNotEmpty) {
            setState(() {
              _data['resource'] = res.first;
            });
          }
        } catch (_) {}
      }
    });
  }

  UserRoleInfo get _role => _data['role'] as UserRoleInfo;

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      final fresh = await _service.fetchDashboardSummary();
      if (mounted) {
        setState(() {
          _data = fresh;
          _isOnline = true;
          if (_role.isUser) {
            _selectedTab = 0;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOnline = false);
      }
      _showSnack('Gagal memuat ulang: ${e.toString().replaceFirst("Exception: ", "")}', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _switchRouter() async {
    _liveHeartbeatTimer?.cancel();
    await _service.dispose();
    await ProfileStorageService().setActiveProfileId(null);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfileListScreen()),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mode User dikunci hanya ke tab Ringkasan & Perangkat
    final showSwitcher = _role.isTechnician;
    final activeTab = _role.isTechnician ? _selectedTab : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _data['identity']?.toString() ?? widget.profile.label,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // REAL-TIME 1:1 LIVE STATUS PILL
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isOnline ? const Color(0xFF34C759).withValues(alpha: 0.12) : const Color(0xFFFF3B30).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _isOnline ? const Color(0xFF34C759).withValues(alpha: 0.3) : const Color(0xFFFF3B30).withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _isOnline ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOnline ? '1:1 LIVE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _isOnline ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            if (_role.isUser)
              Container(
                margin: const EdgeInsets.only(top: 1),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF007AFF).withValues(alpha: 0.25), width: 0.5),
                ),
                child: const Text(
                  'MODE USER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF007AFF),
                    letterSpacing: 0.3,
                  ),
                ),
              )
            else
              Text(
                '${widget.profile.host} • ${_role.roleBadge}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF8E8E93)),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _refresh,
          ),
          IconButton(
            tooltip: 'Ganti Router',
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: _switchRouter,
          ),
        ],
      ),
      body: Column(
        children: [
          // REAL-TIME NETWORK DOWN WARNING BANNER
          if (!_isOnline)
            Container(
              width: double.infinity,
              color: const Color(0xFFFF3B30),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Jaringan / Router Terputus — Mencoba menyambung kembali...',
                      style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  InkWell(
                    onTap: _refresh,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('Coba Lagi', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  children: [
                    if (showSwitcher) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildTopModeSwitcher(),
                      ),
                    ],
                    Expanded(
                      child: activeTab == 0
                          ? CustomerTabView(
                              data: _data,
                              role: _role,
                              service: _service,
                              onRefresh: _refresh,
                              showSnack: _showSnack,
                            )
                          : WinboxPanelView(
                              service: _service,
                              data: _data,
                              showSnack: _showSnack,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTopModeItem(index: 0, title: 'Ringkasan & Perangkat', icon: Icons.devices_rounded),
          _buildTopModeItem(index: 1, title: 'Winbox PC (Full)', icon: Icons.admin_panel_settings_rounded),
        ],
      ),
    );
  }

  Widget _buildTopModeItem({required int index, required String title, required IconData icon}) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? const Color(0xFF007AFF) : const Color(0xFF6C6C70)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? const Color(0xFF1C1C1E) : const Color(0xFF6C6C70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
