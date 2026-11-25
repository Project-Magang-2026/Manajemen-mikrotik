import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/winbox_models.dart';
import '../services/mikrotik_service.dart';

class WinboxItemInspector extends StatefulWidget {
  final MikroTikService service;
  final WinboxSubMenu subMenu;
  final Map<String, String> item;
  final String primaryTitle;
  final bool canWrite;
  final bool isConfigurable;
  final VoidCallback onUpdated;
  final Function(String, {bool isError}) showSnack;

  const WinboxItemInspector({
    super.key,
    required this.service,
    required this.subMenu,
    required this.item,
    required this.primaryTitle,
    required this.canWrite,
    required this.isConfigurable,
    required this.onUpdated,
    required this.showSnack,
  });

  static Future<void> show({
    required BuildContext context,
    required MikroTikService service,
    required WinboxSubMenu subMenu,
    required Map<String, String> item,
    required String primaryTitle,
    required bool canWrite,
    required bool isConfigurable,
    required VoidCallback onUpdated,
    required Function(String, {bool isError}) showSnack,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFF5F5F7),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => WinboxItemInspector(
        service: service,
        subMenu: subMenu,
        item: item,
        primaryTitle: primaryTitle,
        canWrite: canWrite,
        isConfigurable: isConfigurable,
        onUpdated: onUpdated,
        showSnack: showSnack,
      ),
    );
  }

  @override
  State<WinboxItemInspector> createState() => _WinboxItemInspectorState();
}

class _WinboxItemInspectorState extends State<WinboxItemInspector> {
  static const Color _bgColor = Color(0xFFF5F5F7);
  static const Color _borderColor = Color(0xFFE8E8ED);
  static const Color _primaryColor = Color(0xFF0071E3);
  static const Color _greenColor = Color(0xFF34C759);
  static const Color _redColor = Color(0xFFFF3B30);
  static const Color _textPrimary = Color(0xFF1D1D1F);
  static const Color _textSecondary = Color(0xFF86868B);

  static const Set<String> _readOnlyKeys = {
    '.id',
    'dynamic',
    'invalid',
    'running',
    'active',
    'complete',
    'published',
    'actual-interface',
    'actual-mtu',
    'bytes',
    'total-bytes',
    'packets',
    'total-packets',
    'rx-byte',
    'tx-byte',
    'uptime',
    'last-logged-in',
    'last-logged-out',
    'creation-time',
    'size',
    'expires-after',
    'next-run',
    'run-count',
    'last-started',
    'public-address',
    'status',
  };

  late Map<String, String> _currentItem;
  final TextEditingController _filterCtrl = TextEditingController();
  String _filterQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentItem = Map<String, String>.from(widget.item);
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  String get _basePath {
    final p = widget.subMenu.path;
    return p.endsWith('/print') ? p.substring(0, p.length - 6) : p;
  }

  String get _itemId => _currentItem['.id'] ?? '';

  bool get _canEditItem =>
      widget.canWrite &&
      widget.isConfigurable &&
      _itemId.isNotEmpty &&
      _currentItem['dynamic'] != 'true';

  bool _isEditableKey(String key) {
    if (!_canEditItem) return false;
    if (_readOnlyKeys.contains(key)) return false;
    if (key.startsWith('.')) return false;
    return true;
  }

  bool _isTechnicalValue(String key, String value) {
    final k = key.toLowerCase();
    if (k == '.id' ||
        k.contains('address') ||
        k.contains('mac') ||
        k.contains('gateway') ||
        k.contains('path') ||
        k.contains('interface') ||
        k.contains('port') ||
        k.contains('mtu') ||
        k.contains('vlan') ||
        k.contains('key') ||
        k.contains('limit') ||
        k.contains('range') ||
        k.contains('subnet') ||
        k.contains('dns') ||
        k.contains('id')) {
      return true;
    }
    if (value.contains('.') || value.contains(':') || value.contains('/')) {
      return true;
    }
    return RegExp(r'^[0-9a-fA-F\-]+$').hasMatch(value);
  }

  List<MapEntry<String, String>> get _sortedFilteredEntries {
    final q = _filterQuery.trim().toLowerCase();
    final entries = _currentItem.entries.where((e) {
      if (q.isEmpty) return true;
      return e.key.toLowerCase().contains(q) || e.value.toLowerCase().contains(q);
    }).toList();

    entries.sort((a, b) {
      int rank(String k) {
        if (k == '.id') return 0;
        if (k == widget.subMenu.primaryField) return 1;
        if (k == widget.subMenu.secondaryField) return 2;
        if (k == 'comment') return 3;
        return 4;
      }

      final ra = rank(a.key);
      final rb = rank(b.key);
      if (ra != rb) return ra.compareTo(rb);
      return a.key.compareTo(b.key);
    });
    return entries;
  }

  void _copyValue(String key, String value) {
    Clipboard.setData(ClipboardData(text: value));
    widget.showSnack('Disalin ($key): $value');
  }

  String _formatActionError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('permission') ||
        lower.contains('not enough') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('policy')) {
      return 'Izin ditolak oleh RouterOS: akun tidak memiliki hak akses write/full untuk mengubah properti ini.';
    }
    return raw.replaceFirst('Exception: ', '');
  }

  Future<bool> _confirmEdit({
    required String title,
    required String message,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF3C3C43), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: _textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _editProperty({
    required String key,
    required String currentValue,
  }) async {
    if (!_canEditItem || _isSaving) return;

    final isComment = key == 'comment';
    final valueCtrl = TextEditingController(text: currentValue);
    final newValue = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          isComment ? 'Ubah Komentar' : 'Edit Properti "$key"',
          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Item: ${widget.primaryTitle} ($_itemId)',
              style: const TextStyle(fontSize: 12, color: _textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: valueCtrl,
              autofocus: true,
              style: TextStyle(
                fontSize: 13.5,
                fontFamily: isComment ? null : 'monospace',
                color: _textPrimary,
              ),
              decoration: InputDecoration(
                hintText: isComment ? 'Masukkan komentar...' : 'Masukkan nilai baru...',
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
            onPressed: () => Navigator.pop(ctx, valueCtrl.text.trim()),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), valueCtrl.dispose);

    if (newValue == null || newValue == currentValue || !mounted) return;

    final confirmed = await _confirmEdit(
      title: isComment ? 'Konfirmasi Ubah Komentar' : 'Konfirmasi Ubah Properti',
      message:
          'Terapkan perubahan pada "${widget.primaryTitle}"?\n\n• $key: ${newValue.isEmpty ? "(Kosong)" : newValue}',
    );
    if (!confirmed) return;

    setState(() => _isSaving = true);
    try {
      if (isComment) {
        await widget.service.setComment(_basePath, _itemId, newValue);
      } else {
        await widget.service.setItemProperties(_basePath, _itemId, {key: newValue});
      }
      if (!mounted) return;
      setState(() {
        _currentItem[key] = newValue;
      });
      widget.showSnack('Properti "$key" berhasil diperbarui.');
      widget.onUpdated();
    } catch (e) {
      if (!mounted) return;
      widget.showSnack('Gagal: ${_formatActionError(e.toString())}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showCustomPropertyEditor() async {
    if (!_canEditItem || _isSaving) return;

    final editableKeys = _currentItem.keys.where(_isEditableKey).toList()..sort();
    final keyCtrl = TextEditingController(
      text: editableKeys.isNotEmpty ? editableKeys.first : '',
    );
    final valCtrl = TextEditingController(
      text: editableKeys.isNotEmpty ? (_currentItem[editableKeys.first] ?? '') : '',
    );
    String? formError;

    final payload = await showDialog<MapEntry<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text(
              'Edit Properti Dasar',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: _textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nama Properti (Key)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C6C70)),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: keyCtrl,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: 'mis. comment, address, max-limit',
                      filled: true,
                      fillColor: const Color(0xFFF2F2F7),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (k) {
                      final trimmed = k.trim();
                      if (_currentItem.containsKey(trimmed)) {
                        valCtrl.text = _currentItem[trimmed] ?? '';
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Nilai Baru (Value)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C6C70)),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: valCtrl,
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Masukkan nilai baru...',
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
                      style: const TextStyle(fontSize: 12, color: _redColor),
                    ),
                  ],
                ],
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
                  final k = keyCtrl.text.trim();
                  if (k.isEmpty) {
                    setDialogState(() => formError = 'Nama properti (key) wajib diisi.');
                    return;
                  }
                  Navigator.pop(ctx, MapEntry(k, valCtrl.text.trim()));
                },
                child: const Text('Lanjutkan'),
              ),
            ],
          );
        },
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      keyCtrl.dispose();
      valCtrl.dispose();
    });

    if (payload == null || !mounted) return;

    final confirmed = await _confirmEdit(
      title: 'Konfirmasi Set Properti',
      message:
          'Ubah properti pada "${widget.primaryTitle}" ($_itemId)?\n\n• ${payload.key}: ${payload.value.isEmpty ? "(Kosong)" : payload.value}',
    );
    if (!confirmed) return;

    setState(() => _isSaving = true);
    try {
      await widget.service.setItemProperties(_basePath, _itemId, {payload.key: payload.value});
      if (!mounted) return;
      setState(() {
        _currentItem[payload.key] = payload.value;
      });
      widget.showSnack('Properti "${payload.key}" berhasil disimpan.');
      widget.onUpdated();
    } catch (e) {
      if (!mounted) return;
      widget.showSnack('Gagal: ${_formatActionError(e.toString())}', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _sortedFilteredEntries;
    final isDisabled = _currentItem['disabled'] == 'true';
    final isRunning = _currentItem['running'] == 'true';
    final isActive = _currentItem['active'] == 'true';
    final isDynamic = _currentItem['dynamic'] == 'true';

    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 14, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                border: Border(bottom: BorderSide(color: _borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${widget.subMenu.title.toUpperCase()} • $_basePath',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: _textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.primaryTitle,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              children: [
                                if (_itemId.isNotEmpty) _buildBadge(_itemId, _primaryColor, isMono: true),
                                if (isDisabled) _buildBadge('Disabled', _redColor),
                                if (!isDisabled && (isRunning || isActive))
                                  _buildBadge(isRunning ? 'Running' : 'Active', _greenColor),
                                if (isDynamic) _buildBadge('Dynamic', _textSecondary),
                                if (!widget.canWrite)
                                  _buildBadge('Read-Only', const Color(0xFFFF9500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: _textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_isSaving)
              const LinearProgressIndicator(
                minHeight: 2,
                color: _primaryColor,
                backgroundColor: _borderColor,
              ),
            if (_currentItem.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: TextField(
                    controller: _filterCtrl,
                    style: const TextStyle(fontSize: 13, color: _textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Cari properti (key atau value)...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFAEAEB2)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFFAEAEB2)),
                      suffixIcon: _filterQuery.isNotEmpty
                          ? IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, size: 16, color: _textSecondary),
                              onPressed: () {
                                _filterCtrl.clear();
                                setState(() => _filterQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _filterQuery = v),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DETAIL PROPERTI (${entries.length})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: _textSecondary,
                        ),
                      ),
                      if (_canEditItem)
                        const Text(
                          'Salin atau Edit nilai',
                          style: TextStyle(fontSize: 10.5, color: _primaryColor, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _borderColor),
                      ),
                      child: const Text(
                        'Tidak ada properti yang cocok dengan pencarian.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: _textSecondary),
                      ),
                    )
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
                          children: List.generate(entries.length, (index) {
                            final e = entries[index];
                            final isMono = _isTechnicalValue(e.key, e.value);
                            final editable = _isEditableKey(e.key);
                            return Column(
                              children: [
                                if (index > 0) const Divider(height: 1, color: Color(0xFFF2F2F7)),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 118,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            e.key,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: SelectableText(
                                            e.value.isEmpty ? '-' : e.value,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontFamily: isMono ? 'monospace' : null,
                                              fontWeight: FontWeight.w500,
                                              color: _textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Salin nilai ${e.key}',
                                        icon: const Icon(Icons.copy_rounded, size: 15, color: _textSecondary),
                                        onPressed: () => _copyValue(e.key, e.value),
                                      ),
                                      if (editable)
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Edit ${e.key}',
                                          icon: const Icon(Icons.edit_outlined, size: 16, color: _primaryColor),
                                          onPressed: _isSaving
                                              ? null
                                              : () => _editProperty(key: e.key, currentValue: e.value),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_canEditItem)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: _borderColor)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primaryColor,
                            side: const BorderSide(color: _borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: _isSaving
                              ? null
                              : () => _editProperty(
                                    key: 'comment',
                                    currentValue: _currentItem['comment'] ?? '',
                                  ),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Komentar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: _isSaving ? null : _showCustomPropertyEditor,
                          icon: const Icon(Icons.tune_rounded, size: 17),
                          label: const Text('Edit Properti', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBadge(String label, Color color, {bool isMono = false}) {
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
          fontFamily: isMono ? 'monospace' : null,
          color: color,
        ),
      ),
    );
  }
}
