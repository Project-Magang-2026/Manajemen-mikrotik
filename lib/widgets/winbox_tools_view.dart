import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/mikrotik_service.dart';

class PingToolWidget extends StatefulWidget {
  final MikroTikService service;

  const PingToolWidget({super.key, required this.service});

  @override
  State<PingToolWidget> createState() => _PingToolWidgetState();
}

class _PingToolWidgetState extends State<PingToolWidget> {
  final _targetController = TextEditingController(text: '8.8.8.8');
  final _countController = TextEditingController(text: '4');
  bool _isLoading = false;
  String _output = '';

  Future<void> _executePing() async {
    final target = _targetController.text.trim();
    final count = int.tryParse(_countController.text.trim()) ?? 4;
    if (target.isEmpty) return;

    setState(() {
      _isLoading = true;
      _output = 'Mengirim ICMP ping ke $target ($count paket)...';
    });

    try {
      final res = await widget.service.pingHost(target, count: count);
      setState(() {
        _output = res.map((r) {
          final host = r['host'] ?? target;
          final time = r['time'] ?? '-';
          final ttl = r['ttl'] ?? '-';
          final status = r['status'] ?? 'OK';
          final size = r['size'] ?? '56';
          return 'Reply from $host: bytes=$size time=$time ttl=$ttl status=$status';
        }).join('\n');
      });
    } catch (e) {
      setState(() => _output = 'Gagal ping: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _targetController,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF1C1C1E)),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF2F2F7),
                        hintText: 'Target IP / Hostname (misal: 8.8.8.8)',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _countController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1C1C1E)),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF2F2F7),
                        hintText: 'Count',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _executePing,
                  child: _isLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Start'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _output.isEmpty ? 'Masukkan target IP dan klik "Start" untuk memulai ping ICMP.' : _output,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF34C759), height: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TracerouteToolWidget extends StatefulWidget {
  final MikroTikService service;

  const TracerouteToolWidget({super.key, required this.service});

  @override
  State<TracerouteToolWidget> createState() => _TracerouteToolWidgetState();
}

class _TracerouteToolWidgetState extends State<TracerouteToolWidget> {
  final _targetController = TextEditingController(text: '8.8.8.8');
  bool _isLoading = false;
  String _output = '';

  Future<void> _executeTraceroute() async {
    final target = _targetController.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isLoading = true;
      _output = 'Traceroute ke $target (menunggu hops)...';
    });

    try {
      final res = await widget.service.fetchMenu('/tool/traceroute/print');
      setState(() {
        _output = res.isEmpty
            ? 'Tidak ada rute hop yang merespons.'
            : res.map((r) => '#${r['hop'] ?? '-'}: ${r['address'] ?? '*'} (loss: ${r['loss'] ?? '0'}% time: ${r['time'] ?? '-'})').join('\n');
      });
    } catch (e) {
      setState(() => _output = 'Gagal traceroute: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _targetController,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Color(0xFF1C1C1E)),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF2F2F7),
                        hintText: 'Target IP (misal: 8.8.8.8)',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _executeTraceroute,
                  child: const Text('Traceroute'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(10)),
              child: SingleChildScrollView(
                child: SelectableText(
                  _output.isEmpty ? 'Masukkan target IP dan klik "Traceroute".' : _output,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF38BDF8), height: 1.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CpuProfileToolWidget extends StatefulWidget {
  final MikroTikService service;

  const CpuProfileToolWidget({super.key, required this.service});

  @override
  State<CpuProfileToolWidget> createState() => _CpuProfileToolWidgetState();
}

class _CpuProfileToolWidgetState extends State<CpuProfileToolWidget> {
  bool _isLoading = false;
  List<Map<String, String>> _processes = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.service.fetchMenu('/tool/profile/print');
      if (mounted) setState(() => _processes = res);
    } catch (_) {
      if (mounted) setState(() => _processes = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CPU LOAD PROFILER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6C6C70))),
              IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _fetchProfile),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _processes.isEmpty
                    ? const Center(child: Text('Tidak ada data CPU profiler.', style: TextStyle(color: Color(0xFF8E8E93))))
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
                        ),
                        child: ListView.separated(
                          itemCount: _processes.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE5E5EA)),
                          itemBuilder: (context, idx) {
                            final p = _processes[idx];
                            final name = p['name'] ?? 'Process $idx';
                            final usage = p['usage'] ?? '0';
                            final cpu = p['cpu'] ?? '0';

                            return ListTile(
                              dense: true,
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              subtitle: Text('CPU Core: $cpu', style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
                              trailing: Text('$usage%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF007AFF))),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class CliTerminalWidget extends StatefulWidget {
  final MikroTikService service;

  const CliTerminalWidget({super.key, required this.service});

  @override
  State<CliTerminalWidget> createState() => _CliTerminalWidgetState();
}

class _CliTerminalWidgetState extends State<CliTerminalWidget> {
  final _cliPathController = TextEditingController(text: '/ip/route/print');
  bool _isLoading = false;
  String _output = '';

  final List<String> _quickCommands = [
    '/system/resource/print',
    '/ip/address/print',
    '/interface/print',
    '/ip/route/print',
    '/ip/dhcp-server/lease/print',
    '/log/print',
    '/ip/firewall/filter/print',
  ];

  @override
  void dispose() {
    _cliPathController.dispose();
    super.dispose();
  }

  Future<void> _runCommand([String? overrideCmd]) async {
    final cmd = (overrideCmd ?? _cliPathController.text).trim();
    if (cmd.isEmpty) return;

    if (overrideCmd != null) {
      _cliPathController.text = overrideCmd;
    }

    setState(() => _isLoading = true);
    try {
      String path = cmd;
      Map<String, String>? params;

      if (cmd.contains(' ')) {
        final parts = cmd.split(RegExp(r'\s+'));
        if (parts.length > 1 && !parts[1].contains('=')) {
          if (parts.every((p) => !p.contains('='))) {
            path = parts.map((p) => p.replaceAll('/', '')).where((p) => p.isNotEmpty).join('/');
            path = '/$path';
          } else {
            path = parts[0];
            params = {};
            for (int i = 1; i < parts.length; i++) {
              final kv = parts[i].split('=');
              if (kv.length == 2) {
                params[kv[0]] = kv[1];
              } else if (kv.length == 1) {
                params['address'] = kv[0];
              }
            }
          }
        } else {
          path = parts[0];
          params = {};
          for (int i = 1; i < parts.length; i++) {
            final kv = parts[i].split('=');
            if (kv.length == 2) {
              params[kv[0]] = kv[1];
            }
          }
        }
      }

      final res = await widget.service.runCommand(path, params: params);
      setState(() {
        _output = res.isEmpty
            ? '(Perintah "$path" berhasil dieksekusi tanpa baris kembalian)'
            : res.map((row) => row.entries.map((e) => '${e.key}=${e.value}').join('  ')).join('\n\n');
      });
    } catch (e) {
      setState(() => _output = 'ERROR: ${e.toString().replaceFirst("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copyOutput() {
    if (_output.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _output));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Output terminal berhasil disalin.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: const Color(0xFF34C759),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearOutput() {
    setState(() => _output = '');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CLI COMMAND BAR (AUTHENTIC DARK TERMINAL THEME)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF3A3A3C), width: 0.8),
                        ),
                        child: TextField(
                          controller: _cliPathController,
                          cursorColor: const Color(0xFF34C759),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF2C2C2E),
                            hintText: 'Ketik perintah RouterOS...',
                            hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontFamily: 'monospace'),
                            isDense: true,
                            prefixIcon: const Icon(Icons.terminal_rounded, size: 16, color: Color(0xFF34C759)),
                            prefixIconConstraints: const BoxConstraints(minWidth: 36, maxWidth: 36),
                            suffixIcon: _cliPathController.text.isNotEmpty
                                ? IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF8E8E93)),
                                    onPressed: () {
                                      _cliPathController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            suffixIconConstraints: const BoxConstraints(minWidth: 32, maxWidth: 32),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                          ),
                          onSubmitted: (_) => _isLoading ? null : _runCommand(),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      ),
                      onPressed: _isLoading ? null : () => _runCommand(),
                      child: _isLoading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Kirim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // QUICK COMMAND CHIPS
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: _quickCommands.map((cmd) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: _isLoading ? null : () => _runCommand(cmd),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF3A3A3C), width: 0.6),
                            ),
                            child: Text(
                              cmd,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                color: Color(0xFF34C759),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // TERMINAL OUTPUT CONSOLE
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Console Top Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                      border: Border(bottom: BorderSide(color: Color(0xFF2C2C2E), width: 0.8)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Color(0xFF34C759), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'OUTPUT TERMINAL ROUTEROS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8E8E93),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        if (_output.isNotEmpty) ...[
                          InkWell(
                            onTap: _copyOutput,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 13, color: Color(0xFF007AFF)),
                                  SizedBox(width: 4),
                                  Text('Salin', style: TextStyle(fontSize: 11, color: Color(0xFF007AFF), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _clearOutput,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFFF453A)),
                                  SizedBox(width: 4),
                                  Text('Bersihkan', style: TextStyle(fontSize: 11, color: Color(0xFFFF453A), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Output Text Area
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SelectableText(
                        _output.isEmpty
                            ? 'MikroTik RouterOS CLI Terminal siap.\nKetik perintah (misal: /ip/address/print) atau tekan chip perintah cepat di atas.'
                            : _output,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          color: _output.isEmpty
                              ? const Color(0xFF8E8E93)
                              : (_output.startsWith('ERROR:') ? const Color(0xFFFF453A) : const Color(0xFF30D158)),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
