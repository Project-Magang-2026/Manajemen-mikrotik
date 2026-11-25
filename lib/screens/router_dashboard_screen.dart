import 'dart:async';
import 'package:flutter/material.dart';
import '../models/router_models.dart';
import '../services/mikrotik_service.dart';
import '../services/profile_storage_service.dart';
import '../widgets/customer_tab_view.dart';
import '../widgets/winbox_panel_view.dart';
import '../widgets/winbox_tools_view.dart';
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
  State<RouterDashboardScreen> createState() =>
      _RouterDashboardScreenState();
}

class _RouterDashboardScreenState extends State<RouterDashboardScreen>
    with WidgetsBindingObserver {
  late MikroTikService _service;
  late Map<String, dynamic> _data;
  bool _isLoading = false;
  int _selectedTab = 0;
  bool _isOnline = true;
  bool _isAppInForeground = true;
  Timer? _heartbeatTimer;
  StreamSubscription<bool>? _connectionSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = MikroTikService(widget.profile);
    _data = widget.initialData;
    _subscribeConnection();
    _syncHeartbeatState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectionSub?.cancel();
    _stopHeartbeat();
    _service.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      _syncHeartbeatState();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _isAppInForeground = false;
      _stopHeartbeat();
    }
  }

  void _subscribeConnection() {
    _connectionSub =
        _service.connectionStateStream.listen((connected) {
      if (!mounted) return;
      if (_isOnline != connected) {
        setState(() => _isOnline = connected);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _syncHeartbeatState() {
    final shouldRun = _isAppInForeground && _selectedTab == 0;
    if (!shouldRun) {
      _stopHeartbeat();
      return;
    }
    if (_heartbeatTimer != null && _heartbeatTimer!.isActive) return;

    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _isLoading || !_isAppInForeground || _selectedTab != 0) {
        return;
      }
      final alive = await _service.checkConnection();
      if (!mounted || !_isAppInForeground || _selectedTab != 0) return;
      if (alive != _isOnline) {
        setState(() => _isOnline = alive);
      }
      if (alive) {
        try {
          final res =
              await _service.fetchMenu('/system/resource/print');
          if (mounted && res.isNotEmpty) {
            setState(() => _data['resource'] = res.first);
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
          if (_role.isUser) _selectedTab = 0;
        });
        _syncHeartbeatState();
      }
    } catch (e) {
      if (mounted) setState(() => _isOnline = false);
      _showSnack('Gagal refresh.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _switchRouter() async {
    _stopHeartbeat();
    await _service.dispose();
    await ProfileStorageService().setActiveProfileId(null);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfileListScreen()),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError
            ? const Color(0xFFFF3B30)
            : const Color(0xFF34C759),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTechnician = _role.isTechnician;
    final activeTab = isTechnician ? _selectedTab : 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    _data['identity']?.toString() ??
                        widget.profile.label,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusPill(),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _role.isUser
                  ? 'MODE USER'
                  : '${widget.profile.host} • ${_role.roleBadge}',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF86868B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _isLoading ? null : _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            onPressed: _switchRouter,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (!_isOnline) _buildOfflineBanner(),
          if (isTechnician) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: _buildTabSwitcher(),
            ),
          ],
          Expanded(
            child: !isTechnician
                ? CustomerTabView(
                    data: _data,
                    role: _role,
                    service: _service,
                    onRefresh: _refresh,
                    showSnack: _showSnack,
                  )
                : IndexedStack(
                    index: activeTab.clamp(0, 2),
                    children: [
                      CustomerTabView(
                        data: _data,
                        role: _role,
                        service: _service,
                        onRefresh: _refresh,
                        showSnack: _showSnack,
                      ),
                      WinboxPanelView(
                        service: _service,
                        data: _data,
                        showSnack: _showSnack,
                      ),
                      WinboxToolsView(
                        service: _service,
                        data: _data,
                        canWrite: _role.canWrite,
                        showSnack: _showSnack,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _isOnline
            ? const Color(0xFF34C759).withOpacity(0.12)
            : const Color(0xFFFF3B30).withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: _isOnline
                  ? const Color(0xFF34C759)
                  : const Color(0xFFFF3B30),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _isOnline ? 'LIVE' : 'OFFLINE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: _isOnline
                  ? const Color(0xFF34C759)
                  : const Color(0xFFFF3B30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFF3B30),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Router tidak terjangkau — mencoba menyambung ulang...',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: _refresh,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8ED),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'Ringkasan', Icons.devices_rounded),
          _buildTabItem(
              1, 'Winbox', Icons.admin_panel_settings_rounded),
          _buildTabItem(2, 'Tools', Icons.build_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title, IconData icon) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          _syncHeartbeatState();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? const Color(0xFF0071E3)
                      : const Color(0xFF86868B)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: selected
                      ? const Color(0xFF1D1D1F)
                      : const Color(0xFF86868B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}