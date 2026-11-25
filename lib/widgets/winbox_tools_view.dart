import 'package:flutter/material.dart';
import '../services/mikrotik_service.dart';

enum WinboxToolSection { ping, logs, backup }

class WinboxToolsView extends StatefulWidget {
  final MikroTikService service;
  final Map<String, dynamic> data;
  final bool canWrite;
  final Function(String, {bool isError}) showSnack;
  final WinboxToolSection initialSection;

  const WinboxToolsView({
    super.key,
    required this.service,
    required this.data,
    required this.canWrite,
    required this.showSnack,
    this.initialSection = WinboxToolSection.ping,
  });

  @override
  State<WinboxToolsView> createState() => _WinboxToolsViewState();
}

class _WinboxToolsViewState extends State<WinboxToolsView> {
  static const Color _bgColor = Color(0xFFF5F5F7);
  static const Color _borderColor = Color(0xFFE8E8ED);
  static const Color _primaryColor = Color(0xFF0071E3);
  static const Color _greenColor = Color(0xFF34C759);
  static const Color _redColor = Color(0xFFFF3B30);
  static const Color _amberColor = Color(0xFFFF9500);
  static const Color _textPrimary = Color(0xFF1D1D1F);
  static const Color _textSecondary = Color(0xFF86868B);

  late WinboxToolSection _activeSection;

  // Ping state
  final TextEditingController _pingTargetCtrl = TextEditingController(text: '8.8.8.8');
  int _pingCount = 4;
  bool _isPinging = false;
  List<Map<String, String>> _pingResults = [];
  String? _pingError;
  bool _hasPingRun = false;

  // Logs state
  final TextEditingController _logFilterCtrl = TextEditingController();
  String _selectedTopic = 'Semua';
  String _logKeyword = '';
  bool _isLoadingLogs = false;
  bool _hasLoadedLogs = false;
  List<Map<String, String>> _logs = [];

  // Backup state
  late TextEditingController _backupNameCtrl;
  bool _isCreatingBackup = false;
  String? _lastBackupName;

  static const List<String> _topicFilters = [
    'Semua',
    'error',
    'warning',
    'info',
    'system',
    'dhcp',
    'wireless',
    'firewall',
    'ppp',
  ];

  @override
  void initState() {
    super.initState();
    _activeSection = widget.initialSection;
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    _backupNameCtrl = TextEditingController(text: 'backup_$stamp');

    if (_activeSection == WinboxToolSection.logs) {
      _loadLogs();
    }
  }

  @override
  void dispose() {
    _pingTargetCtrl.dispose();
    _logFilterCtrl.dispose();
    _backupNameCtrl.dispose();
    super.dispose();
  }

  void _switchSection(WinboxToolSection section) {
    setState(() => _activeSection = section);
    if (section == WinboxToolSection.logs && !_hasLoadedLogs && !_isLoadingLogs) {
      _loadLogs();
    }
  }

  Future<void> _runPing() async {
    final target = _pingTargetCtrl.text.trim();
    if (target.isEmpty) {
      widget.showSnack('Masukkan alamat IP atau hostname tujuan.', isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isPinging = true;
      _pingError = null;
      _pingResults = [];
      _hasPingRun = true;
    });

    try {
      final res = await widget.service.pingHost(target, count: _pingCount);
      if (!mounted) return;
      setState(() {
        _pingResults = res;
        _isPinging = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPinging = false;
        _pingError = e.toString().replaceFirst('Exception: ', '');
      });
      widget.showSnack('Ping gagal: $_pingError', isError: true);
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoadingLogs = true;
    });
    try {
      final res = await widget.service.fetchLogs();
      if (!mounted) return;
      setState(() {
        _logs = res;
        _isLoadingLogs = false;
        _hasLoadedLogs = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLogs = false;
        _hasLoadedLogs = true;
      });
      widget.showSnack('Gagal memuat log: ${e.toString().replaceFirst('Exception: ', '')}', isError: true);
    }
  }

  Future<void> _createBackup() async {
    if (!widget.canWrite) return;
    final name = _backupNameCtrl.text.trim();
    if (name.isEmpty) {
      widget.showSnack('Nama file backup tidak boleh kosong.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Buat Backup Router?',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: _textPrimary),
        ),
        content: Text(
          'Router akan menyimpan file konfigurasi backup dengan nama "$name.backup" ke penyimpanan internal perangkat.',
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
            child: const Text('Buat Backup', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCreatingBackup = true);
    try {
      await widget.service.createBackup(name);
      if (!mounted) return;
      setState(() {
        _isCreatingBackup = false;
        _lastBackupName = '$name.backup';
      });
      widget.showSnack('Backup "$name.backup" berhasil dibuat di router.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreatingBackup = false);
      final raw = e.toString().replaceFirst('Exception: ', '');
      final lower = raw.toLowerCase();
      final msg = (lower.contains('permission') || lower.contains('not enough') || lower.contains('403'))
          ? 'Izin ditolak: akun tidak memiliki hak akses write/backup.'
          : raw;
      widget.showSnack('Gagal membuat backup: $msg', isError: true);
    }
  }

  List<Map<String, String>> get _filteredLogs {
    final kw = _logKeyword.trim().toLowerCase();
    final topic = _selectedTopic.toLowerCase();
    return _logs.where((log) {
      final topics = (log['topics'] ?? '').toLowerCase();
      final msg = (log['message'] ?? '').toLowerCase();
      final time = (log['time'] ?? '').toLowerCase();
      if (_selectedTopic != 'Semua' && !topics.contains(topic)) {
        return false;
      }
      if (kw.isNotEmpty && !topics.contains(kw) && !msg.contains(kw) && !time.contains(kw)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      child: Column(
        children: [
          _buildSectionSwitcher(),
          Expanded(
            child: switch (_activeSection) {
              WinboxToolSection.ping => _buildPingSection(),
              WinboxToolSection.logs => _buildLogsSection(),
              WinboxToolSection.backup => _buildBackupSection(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSwitcher() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _borderColor)),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            _buildSegmentButton(
              section: WinboxToolSection.ping,
              icon: Icons.network_ping_rounded,
              label: 'Ping',
            ),
            _buildSegmentButton(
              section: WinboxToolSection.logs,
              icon: Icons.receipt_long_rounded,
              label: 'Log',
            ),
            _buildSegmentButton(
              section: WinboxToolSection.backup,
              icon: Icons.save_alt_rounded,
              label: 'Backup',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required WinboxToolSection section,
    required IconData icon,
    required String label,
  }) {
    final selected = _activeSection == section;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchSection(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? _primaryColor : _textSecondary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _textPrimary : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PING SECTION
  // ===========================================================================

  Widget _buildPingSection() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionLabel('PING DIAGNOSTIK'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Target IP atau Hostname',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _pingTargetCtrl,
                style: const TextStyle(fontSize: 13.5, fontFamily: 'monospace', color: _textPrimary),
                decoration: InputDecoration(
                  hintText: 'mis. 8.8.8.8 atau 192.168.1.1',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFAEAEB2)),
                  prefixIcon: const Icon(Icons.radar_rounded, size: 18, color: _primaryColor),
                  filled: true,
                  fillColor: _bgColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _borderColor),
                  ),
                ),
                onSubmitted: (_) => _runPing(),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ['8.8.8.8', '1.1.1.1', '192.168.1.1', 'google.com'].map((preset) {
                  return InkWell(
                    onTap: () => setState(() => _pingTargetCtrl.text = preset),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _borderColor),
                      ),
                      child: Text(
                        preset,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: _textPrimary),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Jumlah Paket:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary),
                  ),
                  const SizedBox(width: 8),
                  for (final count in [4, 6, 10]) ...[
                    ChoiceChip(
                      label: Text('${count}x', style: const TextStyle(fontSize: 11.5)),
                      selected: _pingCount == count,
                      selectedColor: _primaryColor.withOpacity(0.15),
                      backgroundColor: _bgColor,
                      side: BorderSide(color: _pingCount == count ? _primaryColor : _borderColor),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _pingCount == count ? _primaryColor : _textSecondary,
                      ),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _pingCount = count),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isPinging ? null : _runPing,
                  icon: _isPinging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 19),
                  label: Text(
                    _isPinging ? 'Mengirim Ping...' : 'Mulai Ping',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_hasPingRun && !_isPinging) ...[
          const SizedBox(height: 16),
          _buildSectionLabel('HASIL PING'),
          const SizedBox(height: 8),
          if (_pingError != null)
            _buildInfoCard(
              icon: Icons.error_outline_rounded,
              color: _redColor,
              title: 'Ping Gagal',
              message: _pingError!,
            )
          else if (_pingResults.isEmpty)
            _buildInfoCard(
              icon: Icons.wifi_off_rounded,
              color: _amberColor,
              title: 'Tidak Ada Balasan',
              message: 'Router tidak menerima balasan ICMP dari "${_pingTargetCtrl.text.trim()}".',
            )
          else
            _buildPingResultsCard(),
        ],
      ],
    );
  }

  Widget _buildPingResultsCard() {
    final last = _pingResults.last;
    final sent = last['sent'] ?? '${_pingResults.length}';
    final received = last['received'] ??
        '${_pingResults.where((r) => (r['time'] ?? '').isNotEmpty).length}';
    final loss = last['packet-loss'] ?? '-';
    final avgRtt = last['avg-rtt'] ?? '';
    final lossNum = int.tryParse(loss.replaceAll('%', '').trim());
    final summaryColor = (lossNum != null && lossNum >= 100)
        ? _redColor
        : (lossNum != null && lossNum > 0)
            ? _amberColor
            : _greenColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: summaryColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: const Border(bottom: BorderSide(color: _borderColor)),
            ),
            child: Row(
              children: [
                Icon(
                  summaryColor == _greenColor
                      ? Icons.check_circle_rounded
                      : (summaryColor == _redColor ? Icons.cancel_rounded : Icons.warning_amber_rounded),
                  size: 20,
                  color: summaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Terkirim: $sent • Diterima: $received • Loss: $loss${loss.contains('%') ? '' : '%'}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textPrimary),
                  ),
                ),
                if (avgRtt.isNotEmpty)
                  Text(
                    'avg $avgRtt',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: summaryColor,
                    ),
                  ),
              ],
            ),
          ),
          ...List.generate(_pingResults.length, (i) {
            final r = _pingResults[i];
            final seq = r['seq'] ?? '${i + 1}';
            final host = r['host'] ?? _pingTargetCtrl.text.trim();
            final time = r['time'] ?? '';
            final ttl = r['ttl'] ?? '';
            final status = r['status'] ?? '';
            final ok = time.isNotEmpty;

            return Column(
              children: [
                if (i > 0) const Divider(height: 1, color: Color(0xFFF2F2F7)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: (ok ? _greenColor : _redColor).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          seq,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ok ? _greenColor : _redColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              host,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: _textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (ttl.isNotEmpty || status.isNotEmpty)
                              Text(
                                [
                                  if (ttl.isNotEmpty) 'TTL=$ttl',
                                  if (status.isNotEmpty) status,
                                ].join(' • '),
                                style: const TextStyle(fontSize: 11, color: _textSecondary),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        ok ? time : 'timeout',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: ok ? _greenColor : _redColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // LOGS SECTION (ON-DEMAND, NO POLLING)
  // ===========================================================================

  Widget _buildLogsSection() {
    final filtered = _filteredLogs;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionLabel('LOG ROUTER TERBARU (${filtered.length})'),
                  InkWell(
                    onTap: _isLoadingLogs ? null : _loadLogs,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isLoadingLogs)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
                            )
                          else
                            const Icon(Icons.refresh_rounded, size: 15, color: _primaryColor),
                          const SizedBox(width: 4),
                          const Text(
                            'Muat Ulang',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _primaryColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: TextField(
                  controller: _logFilterCtrl,
                  style: const TextStyle(fontSize: 13, color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Filter kata kunci log...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFAEAEB2)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFFAEAEB2)),
                    suffixIcon: _logKeyword.isNotEmpty
                        ? IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 16, color: _textSecondary),
                            onPressed: () {
                              _logFilterCtrl.clear();
                              setState(() => _logKeyword = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _logKeyword = v),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _topicFilters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, idx) {
                    final topic = _topicFilters[idx];
                    final selected = _selectedTopic == topic;
                    return ChoiceChip(
                      label: Text(topic, style: const TextStyle(fontSize: 11)),
                      selected: selected,
                      selectedColor: _primaryColor.withOpacity(0.14),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: selected ? _primaryColor : _borderColor),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected ? _primaryColor : _textSecondary,
                      ),
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _selectedTopic = topic),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingLogs && _logs.isEmpty
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: _primaryColor))
              : filtered.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildInfoCard(
                          icon: Icons.receipt_long_outlined,
                          color: _textSecondary,
                          title: 'Log Kosong',
                          message: 'Tidak ada entri log yang sesuai dengan filter saat ini.',
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      color: _primaryColor,
                      onRefresh: _loadLogs,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final log = filtered[i];
                          final topics = log['topics'] ?? 'system';
                          final time = log['time'] ?? '';
                          final message = log['message'] ?? '';
                          final topicLower = topics.toLowerCase();
                          final Color topicColor = topicLower.contains('error') || topicLower.contains('critical')
                              ? _redColor
                              : topicLower.contains('warning')
                                  ? _amberColor
                                  : _primaryColor;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: topicColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        topics,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: topicColor,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      time,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'monospace',
                                        color: _textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  message,
                                  style: const TextStyle(fontSize: 12.5, color: _textPrimary, height: 1.35),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BACKUP SECTION
  // ===========================================================================

  Widget _buildBackupSection() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionLabel('PEMBUAT BACKUP KONFIGURASI'),
        const SizedBox(height: 8),
        if (!widget.canWrite)
          _buildInfoCard(
            icon: Icons.lock_outline_rounded,
            color: _amberColor,
            title: 'Izin Write Diperlukan',
            message:
                'Akun Anda berada pada mode baca (read-only). Pembuatan file backup RouterOS memerlukan izin grup write atau full.',
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nama File Backup',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _backupNameCtrl,
                  style: const TextStyle(fontSize: 13.5, fontFamily: 'monospace', color: _textPrimary),
                  decoration: InputDecoration(
                    hintText: 'mis. backup_distribusi_1',
                    suffixText: '.backup',
                    suffixStyle: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: _textSecondary),
                    filled: true,
                    fillColor: _bgColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _borderColor),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'File backup akan disimpan langsung di penyimpanan internal router (/file) dan kompatibel dengan RouterOS v6 maupun v7.',
                  style: TextStyle(fontSize: 12, color: _textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isCreatingBackup ? null : _createBackup,
                    icon: _isCreatingBackup
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_alt_rounded, size: 18),
                    label: Text(
                      _isCreatingBackup ? 'Menyimpan Backup...' : 'Simpan Backup ke Router',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                ),
                if (_lastBackupName != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _greenColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _greenColor.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18, color: _greenColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Terakhir dibuat: $_lastBackupName',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: _textPrimary,
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
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _textPrimary),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: _textSecondary, height: 1.4),
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
}
