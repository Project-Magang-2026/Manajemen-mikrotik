import 'package:flutter/material.dart';
import '../models/router_models.dart';
import '../services/mikrotik_service.dart';
import '../services/profile_storage_service.dart';
import '../services/router_discovery_service.dart';
import '../services/mikrotik_auto_discovery.dart';
import 'router_dashboard_screen.dart';

class ProfileListScreen extends StatefulWidget {
  const ProfileListScreen({super.key});

  @override
  State<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends State<ProfileListScreen> {
  final _storage = ProfileStorageService();
  final _discoveryService = RouterDiscoveryService();
  final _autoDiscovery = MikrotikAutoDiscovery();

  final _labelController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8728');
  final _userController = TextEditingController(text: 'admin');
  final _passController = TextEditingController();

  List<RouterProfile> _savedProfiles = [];
  bool _isConnecting = false;
  bool _isScanning = false;
  bool _obscurePass = true;
  LoginRolePreference _selectedRolePreference = LoginRolePreference.auto;
  MikrotikDiscoveryResult? _detectedRouter;

  @override
  void initState() {
    super.initState();
    _loadSavedProfiles();
    _startZeroTouchDiscovery();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfiles() async {
    final list = await _storage.getProfiles();
    if (mounted) setState(() => _savedProfiles = list);
  }

  void _startZeroTouchDiscovery() {
    _autoDiscovery.discoverGatewayRouter().then((result) {
      if (!mounted) return;
      if (result != null) {
        setState(() => _detectedRouter = result);
      }
    });
  }

  void _applyAutoDiscovery(MikrotikDiscoveryResult detected) {
    setState(() {
      _ipController.text = detected.gatewayIp;
      _portController.text = detected.apiPort.toString();
      if (_labelController.text.trim().isEmpty) {
        _labelController.text = 'MikroTik (${detected.gatewayIp})';
      }
    });
    _showSnack('Auto-fill: ${detected.gatewayIp}:${detected.apiPort}');
  }

  Future<void> _scanNetwork() async {
    setState(() => _isScanning = true);
    try {
      final found = await _discoveryService.discoverActiveRouter();
      if (!mounted) return;
      if (found != null) {
        setState(() {
          _ipController.text = found.ip;
          _portController.text = found.port.toString();
          if (_labelController.text.trim().isEmpty) {
            _labelController.text = found.label;
          }
        });
        _showSnack('Router ditemukan: ${found.ip}');
      } else {
        _showSnack('Tidak ada router terdeteksi.', isError: true);
      }
    } catch (e) {
      _showSnack('Gagal scan.', isError: true);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectAndSave(RouterProfile profile) async {
    setState(() => _isConnecting = true);
    try {
      final service = MikroTikService(profile);
      final data = await service.fetchDashboardSummary();
      await _storage.saveProfile(profile, setAsActive: false);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RouterDashboardScreen(
            profile: profile,
            initialData: data,
          ),
        ),
      );
    } catch (e) {
      _showSnack(
        'Gagal: ${e.toString().replaceFirst("Exception: ", "")}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _submitNewConnection() {
    final host = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8728;
    final user = _userController.text.trim();
    final pass = _passController.text;
    final label = _labelController.text.trim().isEmpty
        ? host
        : _labelController.text.trim();

    if (host.isEmpty || user.isEmpty) {
      _showSnack('IP dan Username wajib diisi.', isError: true);
      return;
    }

    final protocol = port == 443
        ? ApiProtocol.restApiHttps
        : port == 80
            ? ApiProtocol.restApiHttp
            : ApiProtocol.routerOsApi8728;

    final newProfile = RouterProfile(
      id: '${host}_${user}_$port',
      label: label,
      host: host,
      port: port,
      username: user,
      password: pass,
      protocol: protocol,
      rolePreference: _selectedRolePreference,
    );
    _connectAndSave(newProfile);
  }

  Future<void> _deleteProfile(RouterProfile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Profil?'),
        content: Text('Hapus "${profile.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _storage.deleteProfile(profile.id);
    await _loadSavedProfiles();
    _showSnack('Profil dihapus.');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor:
            isError ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildHeader(),
                const SizedBox(height: 24),
                if (_detectedRouter != null) ...[
                  _buildDiscoveryBanner(_detectedRouter!),
                  const SizedBox(height: 20),
                ],
                if (_savedProfiles.isNotEmpty) ...[
                  _buildSectionLabel('ROUTER TERSIMPAN'),
                  const SizedBox(height: 8),
                  ..._savedProfiles.map((p) => _buildProfileCard(p)),
                  const SizedBox(height: 24),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionLabel('HUBUNGKAN ROUTER'),
                    TextButton.icon(
                      onPressed:
                          _isScanning || _isConnecting ? null : _scanNetwork,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find_rounded, size: 16),
                      label: Text(
                          _isScanning ? 'Scanning...' : 'Scan'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF0071E3),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildConnectionForm(),
                const SizedBox(height: 24),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 13, color: Color(0xFFAEAEB2)),
                    SizedBox(width: 6),
                    Text(
                      'Sesi otomatis berakhir saat app ditutup',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFFAEAEB2)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF0071E3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.router_rounded,
              color: Color(0xFF0071E3), size: 26),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pocket Winbox',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1D1F),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'MikroTik Network Manager',
                style:
                    TextStyle(fontSize: 13, color: Color(0xFF86868B)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryBanner(MikrotikDiscoveryResult detected) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0071E3).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF0071E3).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: Color(0xFF0071E3)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Router MikroTik Terdeteksi',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${detected.gatewayIp}:${detected.apiPort}',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Color(0xFF0071E3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: FilledButton.icon(
              onPressed: () => _applyAutoDiscovery(detected),
              icon: const Icon(Icons.touch_app_rounded, size: 16),
              label: const Text('Isi Otomatis',
                  style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0071E3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF86868B),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildProfileCard(RouterProfile p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8ED)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0071E3).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.router_rounded,
                size: 18, color: Color(0xFF0071E3)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.username}@${p.host}:${p.port}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF86868B),
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Color(0xFFAEAEB2)),
            onPressed: _isConnecting ? null : () => _deleteProfile(p),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 32,
            child: FilledButton(
              onPressed:
                  _isConnecting ? null : () => _connectAndSave(p),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0071E3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Masuk',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildField(
            controller: _labelController,
            label: 'Label Router',
            hint: 'Router Kantor',
            icon: Icons.label_outline_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildField(
                  controller: _ipController,
                  label: 'IP / Host',
                  hint: '192.168.88.1',
                  icon: Icons.language_rounded,
                  mono: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildField(
                  controller: _portController,
                  label: 'Port',
                  hint: '8728',
                  icon: Icons.tag_rounded,
                  mono: true,
                  keyboard: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _userController,
            label: 'Username',
            hint: 'admin',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _passController,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            suffix: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 18,
                color: const Color(0xFF86868B),
              ),
              onPressed: () =>
                  setState(() => _obscurePass = !_obscurePass),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                  minWidth: 36, minHeight: 36),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mode Masuk',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF86868B)),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8E8ED)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<LoginRolePreference>(
                    isExpanded: true,
                    isDense: true,
                    value: _selectedRolePreference,
                    icon: const Icon(Icons.unfold_more_rounded,
                        size: 18, color: Color(0xFF86868B)),
                    items: LoginRolePreference.values.map((pref) {
                      return DropdownMenuItem(
                        value: pref,
                        child: Text(pref.label,
                            style:
                                const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null)
                        setState(
                            () => _selectedRolePreference = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: _isConnecting ? null : _submitNewConnection,
              style: FilledButton.styleFrom(
                backgroundColor: _isConnecting
                    ? const Color(0xFFAEAEB2)
                    : const Color(0xFF0071E3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Hubungkan',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    bool obscure = false,
    bool mono = false,
    Widget? suffix,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF86868B)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          style: TextStyle(
            fontSize: 14,
            fontFamily: mono ? 'monospace' : null,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon,
                    size: 18, color: const Color(0xFFAEAEB2))
                : null,
            suffixIcon: suffix,
            isDense: true,
          ),
        ),
      ],
    );
  }
}