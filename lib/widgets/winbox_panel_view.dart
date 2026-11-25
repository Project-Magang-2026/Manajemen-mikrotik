import 'package:flutter/material.dart';
import '../models/router_models.dart';
import '../models/winbox_models.dart';
import '../services/mikrotik_service.dart';
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
  static const Color _bgColor = Color(0xFFF5F5F7);
  static const Color _borderColor = Color(0xFFE8E8ED);
  static const Color _primaryColor = Color(0xFF0071E3);
  static const Color _greenColor = Color(0xFF34C759);
  static const Color _redColor = Color(0xFFFF3B30);
  static const Color _textPrimary = Color(0xFF1D1D1F);
  static const Color _textSecondary = Color(0xFF86868B);

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _itemFilterController = TextEditingController();

  int _selectedCategoryIndex = 0;
  String _searchQuery = '';

  WinboxMenuItemReference? _activeMenuRef;
  WinboxToolSection? _activeToolsSection;
  List<Map<String, String>> _items = [];
  bool _isLoadingData = false;
  bool _isExecutingAction = false;
  String? _errorMessage;
  String _itemFilterQuery = '';
  int _requestToken = 0;

  bool get _canWrite {
    final role = widget.data['role'];
    if (role is UserRoleInfo) return role.canWrite;
    return false;
  }

  String _basePath(String path) =>
      path.endsWith('/print') ? path.substring(0, path.length - 6) : path;

  static const Set<String> _readOnlyPaths = {
    '/interface',
    '/interface/ethernet',
    '/interface/bridge/host',
    '/interface/bridge/mdb',
    '/interface/wireless/registration-table',
    '/interface/wifi/registration-table',
    '/caps-man/registration-table',
    '/caps-man/radio',
    '/ip/neighbor',
    '/ip/dns/cache',
    '/ip/firewall/connection',
    '/ip/hotspot/active',
    '/ip/hotspot/host',
    '/ip/hotspot/cookie',
    '/ip/ipsec/active-peers',
    '/ppp/active',
    '/routing/bgp/session',
    '/routing/ospf/neighbor',
    '/mpls/forwarding-table',
    '/mpls/ldp/neighbor',
    '/log',
    '/file',
    '/user/active',
    '/system/resource',
    '/system/routerboard',
    '/system/health',
    '/system/clock',
    '/system/license',
    '/system/package',
    '/system/history',
  };

  static const Set<String> _singletonConfigPaths = {
    '/ip/dns',
    '/ip/cloud',
    '/ip/proxy',
    '/ip/socks',
    '/ip/upnp',
    '/ip/smb',
    '/ip/ssh',
    '/ip/accounting',
    '/ip/traffic-flow',
    '/ip/kid-control',
    '/caps-man/manager',
    '/interface/bridge/settings',
    '/interface/l2tp-server/server',
    '/interface/pptp-server/server',
    '/interface/sstp-server/server',
    '/interface/ovpn-server/server',
    '/interface/wireless/cap',
    '/ppp/aaa',
    '/ip/ipsec/settings',
    '/mpls/ldp',
    '/snmp',
    '/system/identity',
    '/system/watchdog',
    '/system/ntp/client',
    '/system/ntp/server',
    '/system/upgrade',
    '/tool/bandwidth-test',
    '/tool/sniffer',
    '/tool/traffic-flow',
    '/tool/graphing',
    '/tool/e-mail',
    '/tool/sms',
    '/romon',
  };

  bool _isConfigurableMenu(String path) =>
      path.startsWith('/') && !_readOnlyPaths.contains(path);

  bool _isRemovableMenu(String path) =>
      _isConfigurableMenu(path) && !_singletonConfigPaths.contains(path);

  bool _isAddableMenu(String path) => _isRemovableMenu(path);

  @override
  void dispose() {
    _searchController.dispose();
    _itemFilterController.dispose();
    super.dispose();
  }

  WinboxCategory get _activeCategory {
    if (winboxCategories.isEmpty) {
      return const WinboxCategory('Kosong', Icons.folder_off_rounded, []);
    }
    final safeIdx = _selectedCategoryIndex.clamp(0, winboxCategories.length - 1);
    return winboxCategories[safeIdx];
  }

  void _selectCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
  }

  void _openSubMenu(
    int categoryIndex,
    int subMenuIndex,
    WinboxCategory category,
    WinboxSubMenu subMenu,
  ) {
    if (subMenu.path == 'PING_TOOL') {
      _openToolsView(WinboxToolSection.ping);
      return;
    }
    final ref = WinboxMenuItemReference(
      categoryIndex: categoryIndex,
      subMenuIndex: subMenuIndex,
      category: category,
      subMenu: subMenu,
    );
    _itemFilterController.clear();
    setState(() {
      _selectedCategoryIndex = categoryIndex;
      _activeToolsSection = null;
      _activeMenuRef = ref;
      _items = [];
      _errorMessage = null;
      _itemFilterQuery = '';
    });
    _loadSubMenuData();
  }

  void _openToolsView(WinboxToolSection section) {
    _requestToken++;
    setState(() {
      _activeMenuRef = null;
      _activeToolsSection = section;
    });
  }

  void _closeToolsView() {
    setState(() {
      _activeToolsSection = null;
    });
  }

  void _closeSubMenu() {
    _requestToken++;
    _itemFilterController.clear();
    setState(() {
      _activeMenuRef = null;
      _items = [];
      _errorMessage = null;
      _isLoadingData = false;
      _itemFilterQuery = '';
    });
  }

  Future<void> _loadSubMenuData() async {
    final ref = _activeMenuRef;
    if (ref == null) return;

    final path = ref.subMenu.path;
    if (!path.startsWith('/')) {
      setState(() {
        _isLoadingData = false;
        _errorMessage = null;
        _items = [];
      });
      return;
    }

    final token = ++_requestToken;
    setState(() {
      _isLoadingData = true;
      _errorMessage = null;
    });

    final printPath = path.endsWith('/print') ? path : '$path/print';

    try {
      final result = await widget.service.fetchMenu(printPath);
      if (!mounted || token != _requestToken) return;
      setState(() {
        _items = result;
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _isLoadingData = false;
        _errorMessage = _formatFriendlyError(e.toString(), ref.subMenu);
      });
    }
  }

  String _formatFriendlyError(String raw, WinboxSubMenu subMenu) {
    final lower = raw.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('not enough') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('policy')) {
      return 'Akses ke "${subMenu.title}" dibatasi oleh hak akses akun RouterOS (membutuhkan izin read/write yang sesuai).';
    }
    if (lower.contains('no such command') ||
        lower.contains('404') ||
        lower.contains('not found') ||
        lower.contains('invalid command')) {
      return 'Menu "${subMenu.title}" (${subMenu.path}) tidak tersedia pada versi RouterOS perangkat ini (mis. fitur khusus RouterOS v7 pada RouterOS v6).';
    }
    if (lower.contains('timeout') || lower.contains('socket') || lower.contains('connection')) {
      return 'Koneksi ke router terputus atau timeout saat memuat "${subMenu.title}". Periksa jaringan lalu coba lagi.';
    }
    return 'Gagal memuat "${subMenu.title}": $raw';
  }

  List<Map<String, String>> get _filteredItems {
    final q = _itemFilterQuery.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((item) {
      return item.entries.any(
        (e) => e.key.toLowerCase().contains(q) || e.value.toLowerCase().contains(q),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _activeToolsSection != null
            ? _buildToolsContainer(_activeToolsSection!)
            : _activeMenuRef != null
                ? _buildSubMenuDataView(_activeMenuRef!)
                : _buildBrowserView(),
      ),
    );
  }

  Widget _buildToolsContainer(WinboxToolSection section) {
    return Column(
      key: ValueKey('winbox_tools_${section.name}'),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
          ),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _closeToolsView,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _primaryColor),
                tooltip: 'Kembali ke daftar menu',
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.build_rounded, size: 17, color: _primaryColor),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tools & Diagnostik',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Ping • Log Terbaru • Backup Ringan',
                      style: TextStyle(fontSize: 11, color: _textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: WinboxToolsView(
            service: widget.service,
            data: widget.data,
            canWrite: _canWrite,
            showSnack: widget.showSnack,
            initialSection: section,
          ),
        ),
      ],
    );
  }

  Widget _buildBrowserView() {
    final searchResults = _searchQuery.trim().isNotEmpty
        ? searchWinboxMenus(_searchQuery)
        : <WinboxMenuItemReference>[];

    return Column(
      key: const ValueKey('winbox_browser'),
      children: [
        _buildSearchHeader(),
        Expanded(
          child: _searchQuery.trim().isNotEmpty
              ? _buildSearchResultsList(searchResults)
              : _buildCategoryBrowser(),
        ),
      ],
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: _bgColor,
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13.5, color: _textPrimary),
          decoration: InputDecoration(
            hintText: 'Cari menu atau path (mis. /ip/address, firewall)...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFAEAEB2)),
            prefixIcon: const Icon(Icons.search_rounded, size: 19, color: Color(0xFFAEAEB2)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18, color: _textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
    );
  }

  Widget _buildCategoryBrowser() {
    final activeCategory = _activeCategory;
    final subMenus = activeCategory.subMenus;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionLabel('KATEGORI WINBOX (${winboxCategories.length})'),
            _buildConnectionBadge(),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: winboxCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = winboxCategories[index];
              final isSelected = index == _selectedCategoryIndex;
              return _buildCategoryCard(cat, index, isSelected);
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionLabel('DIAGNOSTIK & UTILITAS CEPAT'),
        const SizedBox(height: 8),
        _buildQuickToolsCard(),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionLabel('SUBMENU • ${activeCategory.title.toUpperCase()}'),
            ),
            Text(
              '${subMenus.length} menu',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (subMenus.isEmpty)
          _buildEmptyCard('Tidak ada submenu pada kategori ini.')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: List.generate(subMenus.length, (idx) {
                  final sub = subMenus[idx];
                  return Column(
                    children: [
                      if (idx > 0) const Divider(height: 1, color: Color(0xFFF2F2F7), indent: 56),
                      _buildSubMenuTile(
                        category: activeCategory,
                        subMenu: sub,
                        onTap: () => _openSubMenu(_selectedCategoryIndex, idx, activeCategory, sub),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickToolsCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          _buildQuickToolButton(
            icon: Icons.network_ping_rounded,
            label: 'Ping',
            onTap: () => _openToolsView(WinboxToolSection.ping),
          ),
          const SizedBox(width: 8),
          _buildQuickToolButton(
            icon: Icons.receipt_long_rounded,
            label: 'Log Terbaru',
            onTap: () => _openToolsView(WinboxToolSection.logs),
          ),
          const SizedBox(width: 8),
          _buildQuickToolButton(
            icon: Icons.save_alt_rounded,
            label: 'Backup',
            onTap: () => _openToolsView(WinboxToolSection.backup),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: _bgColor,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: _primaryColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(WinboxCategory category, int index, bool isSelected) {
    return Material(
      color: isSelected ? _primaryColor : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _selectCategory(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 114,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _primaryColor : _borderColor,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    category.icon,
                    size: 20,
                    color: isSelected ? Colors.white : _primaryColor,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.22) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${category.subMenus.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : _textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                category.title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : _textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsList(List<WinboxMenuItemReference> results) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionLabel('HASIL PENCARIAN (${results.length})'),
            _buildConnectionBadge(),
          ],
        ),
        const SizedBox(height: 8),
        if (results.isEmpty)
          _buildEmptyCard('Menu atau path "$_searchQuery" tidak ditemukan.')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: List.generate(results.length, (idx) {
                  final ref = results[idx];
                  return Column(
                    children: [
                      if (idx > 0) const Divider(height: 1, color: Color(0xFFF2F2F7), indent: 56),
                      _buildSubMenuTile(
                        category: ref.category,
                        subMenu: ref.subMenu,
                        categoryBadge: ref.category.title,
                        onTap: () => _openSubMenu(
                          ref.categoryIndex,
                          ref.subMenuIndex,
                          ref.category,
                          ref.subMenu,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubMenuTile({
    required WinboxCategory category,
    required WinboxSubMenu subMenu,
    required VoidCallback onTap,
    String? categoryBadge,
  }) {
    final isSpecial = !subMenu.path.startsWith('/');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                category.icon,
                size: 17,
                color: _primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subMenu.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (categoryBadge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            categoryBadge,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subMenu.path,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: isSpecial ? null : 'monospace',
                      color: _textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (subMenu.displayColumns.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _borderColor),
                ),
                child: Text(
                  '${subMenu.displayColumns.length} kol',
                  style: const TextStyle(fontSize: 10, color: _textSecondary, fontWeight: FontWeight.w500),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFAEAEB2)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SUBMENU DATA VIEW
  // ===========================================================================

  Widget _buildSubMenuDataView(WinboxMenuItemReference ref) {
    final subMenu = ref.subMenu;
    final filtered = _filteredItems;

    return Column(
      key: ValueKey('winbox_data_${subMenu.path}'),
      children: [
        _buildSubMenuHeaderBar(ref),
        if ((_isLoadingData && _items.isNotEmpty) || _isExecutingAction)
          const LinearProgressIndicator(
            minHeight: 2,
            color: _primaryColor,
            backgroundColor: _borderColor,
          ),
        if (subMenu.path.startsWith('/') && (_items.isNotEmpty || _itemFilterQuery.isNotEmpty))
          _buildItemFilterBar(subMenu),
        Expanded(
          child: _buildSubMenuBody(ref, filtered),
        ),
      ],
    );
  }

  Widget _buildSubMenuHeaderBar(WinboxMenuItemReference ref) {
    final subMenu = ref.subMenu;
    final showAdd = _canWrite && _isAddableMenu(subMenu.path);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _closeSubMenu,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _primaryColor),
            tooltip: 'Kembali ke daftar menu',
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(ref.category.icon, size: 17, color: _primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subMenu.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  '${ref.category.title} • ${subMenu.path}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: _textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (subMenu.path.startsWith('/')) ...[
            if (!_canWrite) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Read-Only',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9500),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Text(
                '${_items.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ),
            if (showAdd) ...[
              const SizedBox(width: 2),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _isExecutingAction ? null : () => _showAddItemDialog(subMenu),
                tooltip: 'Tambah ${subMenu.title}',
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: _primaryColor),
              ),
            ],
            const SizedBox(width: 2),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _isLoadingData ? null : _loadSubMenuData,
              tooltip: 'Muat ulang',
              icon: _isLoadingData
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20, color: _primaryColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemFilterBar(WinboxSubMenu subMenu) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      color: _bgColor,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor),
        ),
        child: TextField(
          controller: _itemFilterController,
          style: const TextStyle(fontSize: 13, color: _textPrimary),
          decoration: InputDecoration(
            hintText: 'Filter data ${subMenu.title}...',
            hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFAEAEB2)),
            prefixIcon: const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFFAEAEB2)),
            suffixIcon: _itemFilterQuery.isNotEmpty
                ? IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 17, color: _textSecondary),
                    onPressed: () {
                      _itemFilterController.clear();
                      setState(() => _itemFilterQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _itemFilterQuery = v),
        ),
      ),
    );
  }

  Widget _buildSubMenuBody(WinboxMenuItemReference ref, List<Map<String, String>> filtered) {
    final subMenu = ref.subMenu;

    if (!subMenu.path.startsWith('/')) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStateCard(
            icon: Icons.build_circle_outlined,
            iconColor: _primaryColor,
            title: subMenu.title,
            message:
                'Menu "${subMenu.title}" (${subMenu.path}) adalah aksi atau utilitas interaktif khusus dan bukan tabel daftar data API.',
            actionLabel: 'Kembali ke Menu',
            onAction: _closeSubMenu,
          ),
        ],
      );
    }

    if (_isLoadingData && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: _primaryColor),
                ),
                const SizedBox(height: 14),
                Text(
                  'Memuat ${subMenu.title}...',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subMenu.path,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStateCard(
            icon: Icons.error_outline_rounded,
            iconColor: _redColor,
            title: 'Tidak Dapat Memuat Data',
            message: _errorMessage!,
            actionLabel: 'Coba Lagi',
            onAction: _loadSubMenuData,
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      final resource = widget.data['resource'] as Map<String, String>?;
      final version = resource?['version'] ?? '';
      final isV6 = version.startsWith('6');
      final role = widget.data['role'];
      final isReadOnly = (role != null && (role.isReadOnly == true));

      final hints = <String>[
        'Belum ada entri data pada menu "${subMenu.title}".',
        if (isV6)
          'Router terdeteksi menggunakan RouterOS v$version — beberapa menu khusus v7 atau paket opsional mungkin tidak tersedia.'
        else
          'Jika menu ini seharusnya berisi data, fitur tersebut mungkin tidak tersedia di versi RouterOS perangkat (seperti RouterOS v6) atau tidak aktif.',
        if (isReadOnly)
          'Akun Anda saat ini berada pada mode baca (read-only), sehingga menu yang membutuhkan hak akses write/admin dapat dibatasi.',
      ];

      return RefreshIndicator(
        color: _primaryColor,
        onRefresh: _loadSubMenuData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStateCard(
              icon: Icons.inbox_outlined,
              iconColor: _textSecondary,
              title: 'Data Kosong / Tidak Tersedia',
              message: hints.join('\n\n'),
              actionLabel: 'Muat Ulang',
              onAction: _loadSubMenuData,
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEmptyCard('Tidak ada item yang cocok dengan "$_itemFilterQuery".'),
        ],
      );
    }

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: _loadSubMenuData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildDataItemCard(filtered[index], subMenu),
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: _textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: onAction,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _resolvePrimaryValue(Map<String, String> item, WinboxSubMenu subMenu) {
    final direct = item[subMenu.primaryField]?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    for (final fallbackKey in ['name', 'address', 'dst-address', 'list', 'user', 'comment', '.id']) {
      final val = item[fallbackKey]?.trim() ?? '';
      if (val.isNotEmpty) return val;
    }

    for (final entry in item.entries) {
      if (entry.value.trim().isNotEmpty) return '${entry.key}: ${entry.value}';
    }
    return '(Tanpa Judul)';
  }

  String? _resolveSecondaryValue(Map<String, String> item, WinboxSubMenu subMenu, String primaryValue) {
    final secField = subMenu.secondaryField;
    if (secField == null || secField.isEmpty) return null;
    final val = item[secField]?.trim() ?? '';
    if (val.isEmpty || val == primaryValue) return null;
    return '$secField: $val';
  }

  Widget _buildDataItemCard(Map<String, String> item, WinboxSubMenu subMenu) {
    final primaryValue = _resolvePrimaryValue(item, subMenu);
    final secondaryValue = _resolveSecondaryValue(item, subMenu, primaryValue);

    final isDisabled = item['disabled'] == 'true';
    final isInvalid = item['invalid'] == 'true';
    final isRunning = item['running'] == 'true';
    final isActive = item['active'] == 'true';
    final isDynamic = item['dynamic'] == 'true';

    final skipKeys = <String>{
      subMenu.primaryField,
      if (subMenu.secondaryField != null) subMenu.secondaryField!,
      '.id',
      'disabled',
      'invalid',
      'running',
      'active',
      'dynamic',
      'comment',
    };

    final displayEntries = <MapEntry<String, String>>[];
    for (final col in subMenu.displayColumns) {
      if (skipKeys.contains(col)) continue;
      final val = item[col]?.trim() ?? '';
      if (val.isNotEmpty) {
        displayEntries.add(MapEntry(col, val));
      }
      if (displayEntries.length >= 6) break;
    }

    if (displayEntries.isEmpty) {
      for (final entry in item.entries) {
        if (skipKeys.contains(entry.key) || entry.value.trim().isEmpty) continue;
        displayEntries.add(entry);
        if (displayEntries.length >= 4) break;
      }
    }

    final comment = item['comment']?.trim() ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => WinboxItemInspector.show(
          context: context,
          service: widget.service,
          subMenu: subMenu,
          item: item,
          primaryTitle: primaryValue,
          canWrite: _canWrite,
          isConfigurable: _isConfigurableMenu(subMenu.path),
          onUpdated: _loadSubMenuData,
          showSnack: widget.showSnack,
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryValue,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDisabled ? _textSecondary : _textPrimary,
                            decoration: isDisabled ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (secondaryValue != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            secondaryValue,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: _textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      if (isInvalid) _buildMiniStatusBadge('Invalid', _redColor),
                      if (isDisabled) _buildMiniStatusBadge('Disabled', _redColor),
                      if (!isDisabled && (isRunning || isActive))
                        _buildMiniStatusBadge(isRunning ? 'Running' : 'Active', _greenColor),
                      if (isDynamic) _buildMiniStatusBadge('Dynamic', _textSecondary),
                    ],
                  ),
                ],
              ),
              if (displayEntries.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: displayEntries.map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _borderColor),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 11, color: _textPrimary),
                          children: [
                            TextSpan(
                              text: '${entry.key}: ',
                              style: const TextStyle(color: _textSecondary, fontWeight: FontWeight.w500),
                            ),
                            TextSpan(
                              text: entry.value,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.notes_rounded, size: 13, color: _textSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        comment,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: _textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.length} properti',
                    style: const TextStyle(fontSize: 10.5, color: _textSecondary),
                  ),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat semua key-value',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 15, color: _primaryColor),
                    ],
                  ),
                ],
              ),
              if (_canWrite &&
                  (item['.id'] ?? '').isNotEmpty &&
                  !isDynamic &&
                  (item.containsKey('disabled') ||
                      _isConfigurableMenu(subMenu.path) ||
                      _isRemovableMenu(subMenu.path))) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFF2F2F7)),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (item.containsKey('disabled'))
                      _buildCardActionChip(
                        icon: isDisabled ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        label: isDisabled ? 'Enable' : 'Disable',
                        color: isDisabled ? _greenColor : const Color(0xFFFF9500),
                        onTap: _isExecutingAction
                            ? null
                            : () => _toggleItemEnabled(item, subMenu, primaryValue),
                      ),
                    if (_isConfigurableMenu(subMenu.path))
                      _buildCardActionChip(
                        icon: Icons.edit_note_rounded,
                        label: 'Komentar',
                        color: _primaryColor,
                        onTap: _isExecutingAction
                            ? null
                            : () => _editItemComment(item, subMenu, primaryValue),
                      ),
                    if (_isRemovableMenu(subMenu.path))
                      _buildCardActionChip(
                        icon: Icons.delete_outline_rounded,
                        label: 'Hapus',
                        color: _redColor,
                        onTap: _isExecutingAction
                            ? null
                            : () => _removeItem(item, subMenu, primaryValue),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildConnectionBadge() {
    final isConnected = widget.service.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: (isConnected ? _greenColor : _redColor).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isConnected ? _greenColor : _redColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'Router Terhubung' : 'Terputus',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isConnected ? _greenColor : _redColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 30, color: Color(0xFFD1D1D6)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: _textSecondary,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ===========================================================================
  // OPERATIONAL WRITE ACTIONS (DENGAN KONFIRMASI)
  // ===========================================================================

  String _formatActionError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('not enough') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('policy')) {
      return 'Izin ditolak oleh RouterOS: akun tidak memiliki hak akses write/full untuk tindakan ini.';
    }
    if (lower.contains('already have') || lower.contains('already exists')) {
      return 'Gagal: entri dengan parameter yang sama sudah ada di router.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  Future<bool> _showConfirmActionDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF3C3C43),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive ? _redColor : _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _runWriteAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (!mounted) return;
    setState(() => _isExecutingAction = true);
    try {
      await action();
      if (!mounted) return;
      widget.showSnack(successMessage);
      await _loadSubMenuData();
    } catch (e) {
      if (!mounted) return;
      widget.showSnack('Gagal: ${_formatActionError(e.toString())}', isError: true);
    } finally {
      if (mounted) setState(() => _isExecutingAction = false);
    }
  }

  Future<void> _toggleItemEnabled(
    Map<String, String> item,
    WinboxSubMenu subMenu,
    String primaryValue,
  ) async {
    final id = item['.id'] ?? '';
    if (id.isEmpty || !_canWrite) return;

    final isDisabled = item['disabled'] == 'true';
    final willEnable = isDisabled;
    final verb = willEnable ? 'mengaktifkan' : 'menonaktifkan';
    final label = willEnable ? 'Enable' : 'Disable';

    final confirmed = await _showConfirmActionDialog(
      title: '$label Item?',
      message:
          'Apakah Anda yakin ingin $verb "$primaryValue" ($id) pada menu ${subMenu.title}?',
      confirmLabel: label,
      isDestructive: !willEnable,
    );
    if (!confirmed) return;

    final base = _basePath(subMenu.path);
    final cmd = willEnable ? '$base/enable' : '$base/disable';
    await _runWriteAction(
      action: () => widget.service.executePath(cmd, params: {'.id': id}),
      successMessage:
          '"$primaryValue" berhasil ${willEnable ? "diaktifkan" : "dinonaktifkan"}.',
    );
  }

  Future<void> _removeItem(
    Map<String, String> item,
    WinboxSubMenu subMenu,
    String primaryValue,
  ) async {
    final id = item['.id'] ?? '';
    if (id.isEmpty || !_canWrite) return;

    final confirmed = await _showConfirmActionDialog(
      title: 'Hapus Item?',
      message:
          'Item "$primaryValue" ($id) akan dihapus dari ${subMenu.title}. Tindakan ini tidak dapat dibatalkan.',
      confirmLabel: 'Hapus',
      isDestructive: true,
    );
    if (!confirmed) return;

    final base = _basePath(subMenu.path);
    await _runWriteAction(
      action: () => widget.service.executePath('$base/remove', params: {'.id': id}),
      successMessage: '"$primaryValue" berhasil dihapus dari ${subMenu.title}.',
    );
  }

  Future<void> _editItemComment(
    Map<String, String> item,
    WinboxSubMenu subMenu,
    String primaryValue,
  ) async {
    final id = item['.id'] ?? '';
    if (id.isEmpty || !_canWrite) return;

    final ctrl = TextEditingController(text: item['comment'] ?? '');
    final newComment = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Ubah Komentar',
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item: $primaryValue ($id)',
              style: const TextStyle(fontSize: 12, color: _textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13.5, color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Masukkan komentar...',
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: _textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), ctrl.dispose);

    if (newComment == null || !mounted) return;
    final confirmed = await _showConfirmActionDialog(
      title: 'Konfirmasi Komentar',
      message: 'Terapkan komentar "${newComment.isEmpty ? "(Kosong)" : newComment}" pada "$primaryValue"?',
      confirmLabel: 'Terapkan',
    );
    if (!confirmed) return;

    final base = _basePath(subMenu.path);
    await _runWriteAction(
      action: () => widget.service.setComment(base, id, newComment),
      successMessage: 'Komentar untuk "$primaryValue" berhasil diperbarui.',
    );
  }

  List<_AddFieldSpec> _addFieldsForMenu(WinboxSubMenu subMenu) {
    switch (_basePath(subMenu.path)) {
      case '/ip/address':
        return const [
          _AddFieldSpec(key: 'address', label: 'Address (CIDR)', hint: '192.168.88.1/24', required: true),
          _AddFieldSpec(key: 'interface', label: 'Interface', hint: 'ether1 / bridge', required: true),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      case '/ip/route':
        return const [
          _AddFieldSpec(key: 'dst-address', label: 'Dst. Address', hint: '0.0.0.0/0', required: true),
          _AddFieldSpec(key: 'gateway', label: 'Gateway', hint: '192.168.1.1', required: true),
          _AddFieldSpec(key: 'distance', label: 'Distance', hint: '1', initialValue: '1'),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      case '/ip/dns/static':
        return const [
          _AddFieldSpec(key: 'name', label: 'Domain Name', hint: 'router.lan', required: true),
          _AddFieldSpec(key: 'address', label: 'IP Address', hint: '192.168.88.1', required: true),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      case '/ip/pool':
        return const [
          _AddFieldSpec(key: 'name', label: 'Pool Name', hint: 'dhcp_pool1', required: true),
          _AddFieldSpec(key: 'ranges', label: 'Ranges', hint: '192.168.88.10-192.168.88.254', required: true),
        ];
      case '/ip/firewall/address-list':
        return const [
          _AddFieldSpec(key: 'list', label: 'List Name', hint: 'allowed_ip', required: true),
          _AddFieldSpec(key: 'address', label: 'IP / Subnet', hint: '192.168.88.10', required: true),
          _AddFieldSpec(key: 'timeout', label: 'Timeout', hint: 'Opsional (mis. 1d)'),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      case '/ip/firewall/filter':
        return const [
          _AddFieldSpec(key: 'chain', label: 'Chain', hint: 'input / forward / output', initialValue: 'forward', required: true),
          _AddFieldSpec(key: 'action', label: 'Action', hint: 'accept / drop / reject', initialValue: 'accept', required: true),
          _AddFieldSpec(key: 'src-address', label: 'Src. Address', hint: 'Opsional'),
          _AddFieldSpec(key: 'dst-address', label: 'Dst. Address', hint: 'Opsional'),
          _AddFieldSpec(key: 'protocol', label: 'Protocol', hint: 'tcp / udp / icmp (opsional)'),
          _AddFieldSpec(key: 'dst-port', label: 'Dst. Port', hint: '80,443 (opsional)'),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      case '/ip/firewall/nat':
        return const [
          _AddFieldSpec(key: 'chain', label: 'Chain', hint: 'srcnat / dstnat', initialValue: 'srcnat', required: true),
          _AddFieldSpec(key: 'action', label: 'Action', hint: 'masquerade / dst-nat', initialValue: 'masquerade', required: true),
          _AddFieldSpec(key: 'out-interface', label: 'Out. Interface', hint: 'ether1 (opsional)'),
          _AddFieldSpec(key: 'to-addresses', label: 'To Addresses', hint: 'Opsional'),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      case '/queue/simple':
        return const [
          _AddFieldSpec(key: 'name', label: 'Queue Name', hint: 'client-1', required: true),
          _AddFieldSpec(key: 'target', label: 'Target IP/Interface', hint: '192.168.88.10/32', required: true),
          _AddFieldSpec(key: 'max-limit', label: 'Max Limit (Up/Down)', hint: '10M/20M', required: true),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      case '/ppp/secret':
        return const [
          _AddFieldSpec(key: 'name', label: 'Username', hint: 'user01', required: true),
          _AddFieldSpec(key: 'password', label: 'Password', hint: 'Minimal 6 karakter', required: true),
          _AddFieldSpec(key: 'service', label: 'Service', hint: 'any / pppoe / l2tp', initialValue: 'any'),
          _AddFieldSpec(key: 'profile', label: 'Profile', hint: 'default', initialValue: 'default'),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      case '/interface/vlan':
        return const [
          _AddFieldSpec(key: 'name', label: 'VLAN Name', hint: 'vlan10', required: true),
          _AddFieldSpec(key: 'vlan-id', label: 'VLAN ID', hint: '10', required: true),
          _AddFieldSpec(key: 'interface', label: 'Interface', hint: 'ether1', required: true),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      case '/tool/netwatch':
        return const [
          _AddFieldSpec(key: 'host', label: 'Host IP', hint: '8.8.8.8', required: true),
          _AddFieldSpec(key: 'interval', label: 'Interval', hint: '00:00:10', initialValue: '00:00:10'),
          _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
      default:
        return [
          _AddFieldSpec(
            key: subMenu.primaryField,
            label: subMenu.primaryField,
            hint: 'Nilai ${subMenu.primaryField}',
            required: true,
          ),
          if (subMenu.secondaryField != null && subMenu.secondaryField!.isNotEmpty)
            _AddFieldSpec(
              key: subMenu.secondaryField!,
              label: subMenu.secondaryField!,
              hint: 'Nilai ${subMenu.secondaryField} (opsional)',
            ),
          const _AddFieldSpec(key: 'comment', label: 'Comment', hint: 'Opsional'),
        ];
    }
  }

  Future<void> _showAddItemDialog(WinboxSubMenu subMenu) async {
    if (!_canWrite) return;

    final specs = _addFieldsForMenu(subMenu);
    final controllers = <String, TextEditingController>{
      for (final s in specs) s.key: TextEditingController(text: s.initialValue ?? ''),
    };
    final extraCtrl = TextEditingController();
    String? formError;

    final params = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(
              'Tambah ${subMenu.title}',
              style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: _textPrimary),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _basePath(subMenu.path),
                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: _textSecondary),
                    ),
                    const SizedBox(height: 12),
                    ...specs.map((spec) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spec.required ? '${spec.label} *' : spec.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6C6C70),
                              ),
                            ),
                            const SizedBox(height: 5),
                            TextField(
                              controller: controllers[spec.key],
                              style: const TextStyle(fontSize: 13, color: _textPrimary),
                              decoration: InputDecoration(
                                hintText: spec.hint,
                                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFAEAEB2)),
                                filled: true,
                                fillColor: const Color(0xFFF2F2F7),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Text(
                      'Parameter Tambahan (opsional, key=value)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF6C6C70)),
                    ),
                    const SizedBox(height: 5),
                    TextField(
                      controller: extraCtrl,
                      style: const TextStyle(fontSize: 12.5, fontFamily: 'monospace', color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: 'mis. disabled=no, mtu=1500',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFAEAEB2)),
                        filled: true,
                        fillColor: const Color(0xFFF2F2F7),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    if (formError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        formError!,
                        style: const TextStyle(fontSize: 12, color: _redColor, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: _textSecondary)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final out = <String, String>{};
                  for (final spec in specs) {
                    final val = controllers[spec.key]!.text.trim();
                    if (spec.required && val.isEmpty) {
                      setDialogState(() {
                        formError = 'Field "${spec.label}" wajib diisi.';
                      });
                      return;
                    }
                    if (val.isNotEmpty) out[spec.key] = val;
                  }
                  final rawExtra = extraCtrl.text.trim();
                  if (rawExtra.isNotEmpty) {
                    for (final part in rawExtra.split(',')) {
                      final eq = part.indexOf('=');
                      if (eq > 0) {
                        final k = part.substring(0, eq).trim();
                        final v = part.substring(eq + 1).trim();
                        if (k.isNotEmpty && v.isNotEmpty) out[k] = v;
                      }
                    }
                  }
                  Navigator.pop(ctx, out);
                },
                child: const Text('Lanjutkan'),
              ),
            ],
          );
        },
      ),
    );

    Future<void>.delayed(const Duration(milliseconds: 350), () {
      for (final c in controllers.values) {
        c.dispose();
      }
      extraCtrl.dispose();
    });

    if (params == null || params.isEmpty || !mounted) return;

    final summary = params.entries.map((e) => '• ${e.key}: ${e.value}').join('\n');
    final confirmed = await _showConfirmActionDialog(
      title: 'Konfirmasi Tambah Data',
      message: 'Tambahkan entri baru ke ${subMenu.title}?\n\n$summary',
      confirmLabel: 'Tambahkan',
    );
    if (!confirmed) return;

    final base = _basePath(subMenu.path);
    await _runWriteAction(
      action: () => widget.service.executePath('$base/add', params: params),
      successMessage: 'Entri baru berhasil ditambahkan ke ${subMenu.title}.',
    );
  }
}

class _AddFieldSpec {
  final String key;
  final String label;
  final String hint;
  final String? initialValue;
  final bool required;

  const _AddFieldSpec({
    required this.key,
    required this.label,
    required this.hint,
    this.initialValue,
    this.required = false,
  });
}
