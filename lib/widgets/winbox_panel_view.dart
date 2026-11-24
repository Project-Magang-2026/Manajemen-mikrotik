import 'dart:async';
import 'package:flutter/material.dart';
import '../models/router_models.dart';
import '../models/winbox_models.dart';
import '../services/mikrotik_service.dart';
import 'winbox_dialogs.dart';
import 'winbox_item_inspector.dart';
import 'winbox_tools_view.dart';

class WinboxPanelView extends StatefulWidget {
  final MikroTikService service;
  final Map<String, dynamic> data;
  final Function(String, {bool isError}) showSnack;

  const WinboxPanelView({
    super.key,
    required this.service,
    required this.data,
    required this.showSnack,
  });

  @override
  State<WinboxPanelView> createState() => _WinboxPanelViewState();
}

class _WinboxPanelViewState extends State<WinboxPanelView> {
  int _activeCategory = 6; // Default: IP
  int _activeSubMenu = 0;   // Default: Addresses
  String _searchQuery = '';
  bool _isSearchOpen = false;

  List<Map<String, String>> _currentMenuItems = [];
  bool _isMenuLoading = false;
  final _searchController = TextEditingController();

  bool _safeModeActive = false;
  bool _isAutoSyncLive = true;
  Timer? _liveAutoSyncTimer;

  @override
  void initState() {
    super.initState();
    _loadActiveWinboxSubMenu();
    _startLiveAutoSync();
  }

  @override
  void dispose() {
    _liveAutoSyncTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startLiveAutoSync() {
    _liveAutoSyncTimer?.cancel();
    _liveAutoSyncTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (!mounted || !_isAutoSyncLive || _isMenuLoading || _isSearchOpen || _isSpecialView) return;
      _loadActiveWinboxSubMenu(silent: true);
    });
  }

  WinboxCategory get _activeCat => winboxCategories[_activeCategory];
  WinboxSubMenu get _activeSub => _activeCat.subMenus[_activeSubMenu];

  bool get _isSpecialView {
    final p = _activeSub.path;
    return p == 'PING_TOOL' ||
        p == 'TRACEROUTE_TOOL' ||
        p == 'PROFILE_TOOL' ||
        p == 'CLI_TOOL' ||
        p == 'SYSTEM_REBOOT' ||
        p == 'SYSTEM_SHUTDOWN';
  }

  bool get _isAddable {
    final p = _activeSub.path;
    if (_isSpecialView) return false;
    return p != '/log' &&
        p != '/system/resource' &&
        p != '/system/routerboard' &&
        p != '/system/health' &&
        p != '/user/active';
  }

  Future<void> _loadActiveWinboxSubMenu({bool silent = false}) async {
    final sub = _activeSub;
    if (_isSpecialView) {
      if (!silent && mounted) setState(() => _isMenuLoading = false);
      return;
    }

    if (!silent && mounted) {
      setState(() => _isMenuLoading = true);
    }

    try {
      final printPath = sub.path.endsWith('/print') ? sub.path : '${sub.path}/print';
      final res = await widget.service.fetchMenu(printPath);
      if (mounted) {
        setState(() => _currentMenuItems = res);
      }
    } catch (_) {
      if (!silent && mounted) setState(() => _currentMenuItems = []);
    } finally {
      if (!silent && mounted) setState(() => _isMenuLoading = false);
    }
  }

  List<Map<String, String>> get _filteredItems {
    if (_searchQuery.isEmpty) return _currentMenuItems;
    final q = _searchQuery.toLowerCase();
    return _currentMenuItems.where((item) {
      return item.values.any((v) => v.toLowerCase().contains(q));
    }).toList();
  }

  void _onAdd() {
    final sub = _activeSub;
    final ifaces = (widget.data['interfaces'] as List<Map<String, String>>?) ?? [];

    if (sub.path == '/ip/address') {
      WinboxDialogs.showAddIpDialog(
        context: context,
        service: widget.service,
        interfaces: ifaces,
        onSuccess: _loadActiveWinboxSubMenu,
        showSnack: widget.showSnack,
      );
    } else if (sub.path == '/ip/route') {
      WinboxDialogs.showAddRouteDialog(
        context: context,
        service: widget.service,
        onSuccess: _loadActiveWinboxSubMenu,
        showSnack: widget.showSnack,
      );
    } else if (sub.path == '/queue/simple') {
      WinboxDialogs.showAddQueueDialog(
        context: context,
        service: widget.service,
        onSuccess: _loadActiveWinboxSubMenu,
        showSnack: widget.showSnack,
      );
    } else if (sub.path == '/ppp/secret') {
      WinboxDialogs.showAddPppSecretDialog(
        context: context,
        service: widget.service,
        onSuccess: _loadActiveWinboxSubMenu,
        showSnack: widget.showSnack,
      );
    } else {
      final role = widget.data['role'] as UserRoleInfo?;
      WinboxDialogs.showGenericAddDialog(
        context: context,
        service: widget.service,
        basePath: sub.path,
        canManageUsers: role?.canManageUsers ?? true,
        onSuccess: _loadActiveWinboxSubMenu,
        showSnack: widget.showSnack,
      );
    }
  }

  Future<void> _onToggleItem(Map<String, String> item, bool enable) async {
    final id = item['.id'];
    if (id == null) return;
    final name = item[_activeSub.primaryField] ?? item['name'] ?? item['address'] ?? 'Item';
    final actionText = enable ? 'mengaktifkan (enable)' : 'menonaktifkan (disable)';

    final confirm = await WinboxDialogs.showConfirmActionDialog(
      context: context,
      title: 'Konfirmasi',
      message: 'Apakah Anda yakin ingin $actionText "$name" (${_activeSub.path})?',
      confirmLabel: enable ? 'Yakin (Enable)' : 'Yakin (Disable)',
      confirmColor: enable ? const Color(0xFF34C759) : const Color(0xFFFF9500),
    );
    if (!confirm) return;

    try {
      final cmd = enable ? '${_activeSub.path}/enable' : '${_activeSub.path}/disable';
      await widget.service.executePath(cmd, params: {'.id': id});
      widget.showSnack(enable ? 'Item "$name" diaktifkan (Enabled).' : 'Item "$name" dinonaktifkan (Disabled).');
      await _loadActiveWinboxSubMenu();
    } catch (e) {
      widget.showSnack('Gagal: $e', isError: true);
    }
  }

  void _onCommentItem(Map<String, String> item) {
    final id = item['.id'];
    if (id == null) return;
    final name = item[_activeSub.primaryField] ?? item['name'] ?? item['address'] ?? 'Item';
    final commentCtrl = TextEditingController(text: item['comment'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Winbox Comment ($name)'),
        content: TextField(
          controller: commentCtrl,
          autofocus: true,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF1C1C1E)),
          decoration: const InputDecoration(hintText: 'Tulis komentar untuk item ini...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              final newComment = commentCtrl.text.trim();
              final oldComment = (item['comment'] ?? '').trim();
              if (newComment == oldComment) {
                Navigator.pop(ctx);
                return;
              }

              final confirm = await WinboxDialogs.showConfirmActionDialog(
                context: context,
                title: 'Konfirmasi Ubah Komentar',
                message: 'Apakah Anda sudah yakin ingin menerapkan komentar ini pada "$name"?\n\n• Komentar: "${newComment.isEmpty ? "(dikosongkan)" : newComment}"',
                confirmLabel: 'Yakin & Simpan',
              );
              if (!confirm) return;

              Navigator.pop(ctx);
              try {
                await widget.service.setComment(_activeSub.path, id, newComment);
                widget.showSnack('Komentar untuk "$name" berhasil disimpan.');
                await _loadActiveWinboxSubMenu();
              } catch (e) {
                widget.showSnack('Gagal: $e', isError: true);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _onRemoveItem(Map<String, String> item) async {
    final id = item['.id'];
    if (id == null) return;
    final name = item[_activeSub.primaryField] ?? item['name'] ?? item['address'] ?? 'Item';

    final confirm = await WinboxDialogs.showConfirmActionDialog(
      context: context,
      title: 'Hapus Item (Winbox Remove)?',
      message: 'Apakah Anda yakin ingin menghapus "$name" (${_activeSub.path}) secara permanen dari router?',
      confirmLabel: 'Hapus Permanen',
      isDestructive: true,
    );

    if (confirm) {
      try {
        await widget.service.executePath('${_activeSub.path}/remove', params: {'.id': id});
        widget.showSnack('Item "$name" berhasil dihapus.');
        await _loadActiveWinboxSubMenu();
      } catch (e) {
        widget.showSnack('Gagal: $e', isError: true);
      }
    }
  }

  void _showItemActionSheet(Map<String, String> item) {
    final name = item[_activeSub.primaryField] ?? item['name'] ?? item['address'] ?? 'Detail Item';
    final disabled = item['disabled'] == 'true';
    final hasId = item['.id'] != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),

              // Title Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _activeSub.path,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: disabled ? const Color(0xFFFF3B30).withValues(alpha: 0.1) : const Color(0xFF34C759).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      disabled ? 'NONAKTIF' : 'AKTIF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: disabled ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE5E5EA)),
              const SizedBox(height: 8),

              // Action 1: Edit & Inspector
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: const Color(0xFF007AFF).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_note_rounded, color: Color(0xFF007AFF), size: 20),
                ),
                title: const Text('Detail & Edit Properti', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Lihat dan ubah seluruh konfigurasi RouterOS', style: TextStyle(fontSize: 11.5, color: Color(0xFF8E8E93))),
                onTap: () {
                  Navigator.pop(ctx);
                  WinboxItemInspector.show(
                    context: context,
                    item: item,
                    basePath: _activeSub.path,
                    service: widget.service,
                    onRefresh: _loadActiveWinboxSubMenu,
                    showSnack: widget.showSnack,
                  );
                },
              ),

              // Action 2: Toggle Enable / Disable
              if (hasId)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (disabled ? const Color(0xFF34C759) : const Color(0xFFFF9500)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      disabled ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                      color: disabled ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                      size: 20,
                    ),
                  ),
                  title: Text(disabled ? 'Aktifkan Item (Enable)' : 'Nonaktifkan Item (Disable)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(disabled ? 'Nyalakan kembali item ini di RouterOS' : 'Matikan sementara item ini tanpa menghapusnya', style: const TextStyle(fontSize: 11.5, color: Color(0xFF8E8E93))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onToggleItem(item, disabled);
                  },
                ),

              // Action 3: Comment
              if (hasId)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: const Color(0xFF5856D6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF5856D6), size: 18),
                  ),
                  title: const Text('Beri / Ubah Komentar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Tambahkan catatan identifikasi (;;; comment)', style: TextStyle(fontSize: 11.5, color: Color(0xFF8E8E93))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onCommentItem(item);
                  },
                ),

              // Action 4: Delete
              if (hasId)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: const Color(0xFFFF3B30).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30), size: 20),
                  ),
                  title: const Text('Hapus Item', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFFFF3B30))),
                  subtitle: const Text('Hapus permanen item ini dari konfigurasi router', style: TextStyle(fontSize: 11.5, color: Color(0xFF8E8E93))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onRemoveItem(item);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMenuPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModernMenuPickerSheet(
        activePath: _activeSub.path,
        onSelect: (catIdx, subIdx) {
          Navigator.pop(ctx);
          setState(() {
            _activeCategory = catIdx;
            _activeSubMenu = subIdx;
            _searchQuery = '';
            _isSearchOpen = false;
            _searchController.clear();
          });
          _loadActiveWinboxSubMenu();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _isSearchOpen
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)),
                            decoration: InputDecoration(
                              hintText: 'Cari di ${_activeSub.title}...',
                              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8E8E93)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF8E8E93)),
                          onPressed: () {
                            setState(() {
                              _isSearchOpen = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // TAPPABLE TITLE TO SWITCH MENU
                        InkWell(
                          onTap: _openMenuPicker,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_activeCat.icon, size: 18, color: const Color(0xFF007AFF)),
                                const SizedBox(width: 8),
                                Text(
                                  _activeSub.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1C1C1E),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF8E8E93)),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),

                        // LIVE 1:1 REALTIME PILL
                        InkWell(
                          onTap: () {
                            setState(() => _isAutoSyncLive = !_isAutoSyncLive);
                            widget.showSnack(_isAutoSyncLive ? 'Live Sync 1:1 Aktif (Update tiap 2 detik).' : 'Live Sync dijeda.');
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isAutoSyncLive ? const Color(0xFF34C759).withValues(alpha: 0.12) : const Color(0xFF8E8E93).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _isAutoSyncLive ? const Color(0xFF34C759).withValues(alpha: 0.3) : const Color(0xFF8E8E93).withValues(alpha: 0.3),
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
                                    color: _isAutoSyncLive ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isAutoSyncLive ? '1:1 LIVE' : 'PAUSED',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: _isAutoSyncLive ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // SEARCH ACTION
                        IconButton(
                          tooltip: 'Cari',
                          icon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF1C1C1E)),
                          onPressed: () => setState(() => _isSearchOpen = true),
                        ),

                        // ADD ACTION
                        if (_isAddable)
                          IconButton(
                            tooltip: 'Tambah Item',
                            icon: const Icon(Icons.add_rounded, size: 22, color: Color(0xFF007AFF)),
                            onPressed: _onAdd,
                          ),

                        // MORE OPTIONS
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF1C1C1E)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) async {
                            if (val == 'safe') {
                              setState(() => _safeModeActive = !_safeModeActive);
                              widget.showSnack(_safeModeActive ? 'Safe Mode Aktif.' : 'Safe Mode Dinonaktifkan.');
                            } else if (val == 'refresh') {
                              await _loadActiveWinboxSubMenu();
                            } else if (val == 'terminal') {
                              final ref = findWinboxMenuByPath('CLI_TOOL');
                              if (ref != null) {
                                setState(() {
                                  _activeCategory = ref.categoryIndex;
                                  _activeSubMenu = ref.subMenuIndex;
                                });
                              }
                            } else if (val == 'reboot') {
                              WinboxDialogs.showConfirmRebootDialog(
                                context: context,
                                service: widget.service,
                                showSnack: widget.showSnack,
                              );
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'safe',
                              child: Row(
                                children: [
                                  Icon(Icons.shield_rounded, size: 18, color: _safeModeActive ? const Color(0xFF34C759) : const Color(0xFF8E8E93)),
                                  const SizedBox(width: 10),
                                  Text(_safeModeActive ? 'Safe Mode (Aktif)' : 'Safe Mode'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'refresh',
                              child: Row(
                                children: [
                                  Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF007AFF)),
                                  SizedBox(width: 10),
                                  Text('Segarkan Data'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'terminal',
                              child: Row(
                                children: [
                                  Icon(Icons.terminal_rounded, size: 18, color: Color(0xFF1C1C1E)),
                                  SizedBox(width: 10),
                                  Text('Terminal CLI'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'reboot',
                              child: Row(
                                children: [
                                  Icon(Icons.restart_alt_rounded, size: 18, color: Color(0xFFFF9500)),
                                  SizedBox(width: 10),
                                  Text('Reboot Router'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final sub = _activeSub;

    if (sub.path == 'PING_TOOL') {
      return PingToolWidget(service: widget.service);
    } else if (sub.path == 'TRACEROUTE_TOOL') {
      return TracerouteToolWidget(service: widget.service);
    } else if (sub.path == 'PROFILE_TOOL') {
      return CpuProfileToolWidget(service: widget.service);
    } else if (sub.path == 'CLI_TOOL') {
      return CliTerminalWidget(service: widget.service);
    } else if (sub.path == 'SYSTEM_REBOOT' || sub.path == 'SYSTEM_SHUTDOWN') {
      return _buildSystemActionView(sub);
    }

    if (_isMenuLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final items = _filteredItems;

    return RefreshIndicator(
      onRefresh: _loadActiveWinboxSubMenu,
      child: items.isEmpty
          ? Center(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inbox_rounded, size: 40, color: Color(0xFFC7C7CC)),
                      const SizedBox(height: 10),
                      Text(
                        _currentMenuItems.isEmpty ? 'Belum ada data di ${sub.title}.' : 'Tidak ada hasil untuk "$_searchQuery".',
                        style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      if (_isAddable && _currentMenuItems.isEmpty) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF007AFF),
                            side: const BorderSide(color: Color(0xFF007AFF), width: 0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Tambah Data Baru', style: TextStyle(fontSize: 12.5)),
                          onPressed: _onAdd,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final item = items[idx];
                final primary = item[sub.primaryField] ?? item['name'] ?? item['address'] ?? 'Item $idx';
                final secondary = sub.secondaryField != null ? item[sub.secondaryField!] : null;
                final disabled = item['disabled'] == 'true';
                final running = item['running'] == 'true';
                final comment = item['comment'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _showItemActionSheet(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (comment != null && comment.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                ';;; $comment',
                                style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF007AFF)),
                              ),
                            ),
                          Row(
                            children: [
                              // Status Dot
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: disabled
                                      ? const Color(0xFFFF3B30)
                                      : (running ? const Color(0xFF34C759) : const Color(0xFF8E8E93)),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Primary Field
                              Expanded(
                                child: Text(
                                  primary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: disabled ? const Color(0xFF8E8E93) : const Color(0xFF1C1C1E),
                                    decoration: disabled ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),

                              // Secondary Field
                              if (secondary != null) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F2F7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      secondary,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF6C6C70)),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFC7C7CC)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSystemActionView(WinboxSubMenu sub) {
    final isReboot = sub.path == 'SYSTEM_REBOOT';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isReboot ? Icons.restart_alt_rounded : Icons.power_settings_new_rounded,
                color: isReboot ? const Color(0xFFFF9500) : const Color(0xFFFF3B30),
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                isReboot ? 'Reboot Router MikroTik' : 'Matikan Router',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
              ),
              const SizedBox(height: 6),
              Text(
                isReboot
                    ? 'Router akan memulai ulang seluruh sistem. Sesi aktif akan terputus sesaat.'
                    : 'Router akan dimatikan secara aman. Daya harus dinyalakan kembali secara manual.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF8E8E93), height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isReboot ? const Color(0xFFFF9500) : const Color(0xFFFF3B30),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (isReboot) {
                      WinboxDialogs.showConfirmRebootDialog(
                        context: context,
                        service: widget.service,
                        showSnack: widget.showSnack,
                      );
                    } else {
                      WinboxDialogs.showConfirmShutdownDialog(
                        context: context,
                        service: widget.service,
                        showSnack: widget.showSnack,
                      );
                    }
                  },
                  child: Text(isReboot ? 'Reboot Sekarang' : 'Shutdown Sekarang', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// ULTRA-MINIMALIST MENU PICKER SHEET
// ===========================================================================

class _ModernMenuPickerSheet extends StatefulWidget {
  final String activePath;
  final Function(int categoryIndex, int subMenuIndex) onSelect;

  const _ModernMenuPickerSheet({
    required this.activePath,
    required this.onSelect,
  });

  @override
  State<_ModernMenuPickerSheet> createState() => _ModernMenuPickerSheetState();
}

class _ModernMenuPickerSheetState extends State<_ModernMenuPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final bool _showAllCategories = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = _searchQuery.isNotEmpty ? searchWinboxMenus(_searchQuery) : <WinboxMenuItemReference>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle Bar
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Text('Pilih Menu Winbox', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E))),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF8E8E93)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF1C1C1E)),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF8E8E93)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: 'Cari menu (misal: nat, lease, queue, vlan)...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5EA)),

            // Content Area
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? (searchResults.isEmpty
                      ? const Center(child: Text('Tidak ada menu yang cocok.', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13)))
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: searchResults.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE5E5EA)),
                          itemBuilder: (ctx, idx) {
                            final ref = searchResults[idx];
                            final isCurrent = ref.subMenu.path == widget.activePath;
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              leading: Icon(ref.category.icon, size: 18, color: const Color(0xFF007AFF)),
                              title: Text(
                                ref.subMenu.title,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isCurrent ? const Color(0xFF007AFF) : const Color(0xFF1C1C1E),
                                ),
                              ),
                              subtitle: Text(
                                '${ref.category.title} • ${ref.subMenu.path}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontFamily: 'monospace'),
                              ),
                              trailing: isCurrent ? const Icon(Icons.check_rounded, color: Color(0xFF007AFF), size: 18) : null,
                              onTap: () => widget.onSelect(ref.categoryIndex, ref.subMenuIndex),
                            );
                          },
                        ))
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      children: [
                        // QUICK GROUPS
                        ...quickMenuGroups.map((group) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(group.icon, size: 15, color: group.color),
                                    const SizedBox(width: 6),
                                    Text(
                                      group.title.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: group.color,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: group.paths.map((p) {
                                    final ref = findWinboxMenuByPath(p);
                                    if (ref == null) return const SizedBox.shrink();
                                    final isCurrent = ref.subMenu.path == widget.activePath;

                                    return InkWell(
                                      onTap: () => widget.onSelect(ref.categoryIndex, ref.subMenuIndex),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isCurrent ? const Color(0xFF007AFF) : const Color(0xFFF2F2F7),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isCurrent ? Colors.transparent : const Color(0xFFE5E5EA), width: 0.5),
                                        ),
                                        child: Text(
                                          ref.subMenu.title,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                            color: isCurrent ? Colors.white : const Color(0xFF1C1C1E),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFE5E5EA)),
                        const SizedBox(height: 10),

                        // EXPANDABLE FULL 100+ DIRECTORY
                        Theme(
                          data: Theme.of(ctx).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            leading: const Icon(Icons.folder_special_rounded, color: Color(0xFF007AFF), size: 20),
                            title: const Text('Semua Kategori Winbox (100+ Menu)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            subtitle: const Text('Jelajahi seluruh menu lengkap RouterOS', style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                            children: winboxCategories.asMap().entries.map((cEntry) {
                              final catIdx = cEntry.key;
                              final cat = cEntry.value;

                              return ExpansionTile(
                                tilePadding: const EdgeInsets.only(left: 8),
                                leading: Icon(cat.icon, size: 16, color: const Color(0xFF6C6C70)),
                                title: Text(cat.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                trailing: Text('${cat.subMenus.length}', style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                                children: cat.subMenus.asMap().entries.map((sEntry) {
                                  final subIdx = sEntry.key;
                                  final sub = sEntry.value;
                                  final isCurrent = sub.path == widget.activePath;

                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.only(left: 36, right: 12),
                                    title: Text(
                                      sub.title,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                        color: isCurrent ? const Color(0xFF007AFF) : const Color(0xFF1C1C1E),
                                      ),
                                    ),
                                    subtitle: Text(sub.path, style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93), fontFamily: 'monospace')),
                                    trailing: isCurrent ? const Icon(Icons.check_rounded, color: Color(0xFF007AFF), size: 16) : null,
                                    onTap: () => widget.onSelect(catIdx, subIdx),
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
