import 'package:flutter/material.dart';
import '../models/router_models.dart';
import '../services/mikrotik_service.dart';
import '../services/profile_storage_service.dart';
import '../services/router_discovery_service.dart';
import 'router_dashboard_screen.dart';

class ProfileListScreen extends StatefulWidget {
  const ProfileListScreen({super.key});

  @override
  State<ProfileListScreen> createState() => _ProfileListScreenState();
}

class _ProfileListScreenState extends State<ProfileListScreen> {
  final _storage = ProfileStorageService();
  final _discoveryService = RouterDiscoveryService();

  final _labelController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  List<RouterProfile> _savedProfiles = [];
  bool _isConnecting = false;
  bool _isScanning = false;
  bool _obscurePass = true;
  LoginRolePreference _selectedRolePreference = LoginRolePreference.auto;

  @override
  void initState() {
    super.initState();
    _loadSavedProfiles();
  }

  Future<void> _loadSavedProfiles() async {
    final list = await _storage.getProfiles();
    if (mounted) {
      setState(() => _savedProfiles = list);
    }
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
        _showSnack('Router terdeteksi: ${found.ip}:${found.port}');
      } else {
        _showSnack('Tidak ada router/port API aktif yang terdeteksi di subnet ini.', isError: true);
      }
    } catch (e) {
      _showSnack('Gagal memindai: ${e.toString().replaceFirst("Exception: ", "")}', isError: true);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _connectAndSave(RouterProfile profile) async {
    setState(() => _isConnecting = true);
    try {
      final service = MikroTikService(profile);
      final data = await service.fetchDashboardSummary();
      await _storage.saveProfile(profile, setAsActive: true);

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
        'Gagal terhubung: ${e.toString().replaceFirst("Exception: ", "")}',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _submitNewConnection() {
    final host = _ipController.text.trim();
    final portText = _portController.text.trim();
    final port = int.tryParse(portText) ?? 8777;
    final user = _userController.text.trim();
    final pass = _passController.text;
    final label = _labelController.text.trim().isEmpty ? host : _labelController.text.trim();

    if (host.isEmpty || user.isEmpty) {
      _showSnack('IP Router dan Username wajib diisi.', isError: true);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Profil Router?'),
        content: Text('Hapus profil "${profile.label}" (${profile.host}) dari daftar tersimpan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              elevation: 0,
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
    _showSnack('Profil "${profile.label}" berhasil dihapus.');
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PAGE TITLE (SwiftUI Large Title)
                  const Text(
                    'Koneksi Router',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1C1C1E),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih profil tersimpan atau hubungkan router baru.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                  ),
                  const SizedBox(height: 20),

                  // SAVED PROFILES SECTION
                  if (_savedProfiles.isNotEmpty) ...[
                    _buildSectionHeader('ROUTER TERSIMPAN'),
                    _buildSavedProfilesCard(),
                    const SizedBox(height: 20),
                  ],

                  // NEW CONNECTION FORM SECTION (With Auto-Scan Action)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('HUBUNGKAN ROUTER BARU'),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF007AFF),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _isScanning || _isConnecting ? null : _scanNetwork,
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF007AFF)),
                                )
                              : const Icon(Icons.wifi_find_rounded, size: 16),
                          label: Text(
                            _isScanning ? 'Memindai...' : 'Pindai Wi-Fi',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildConnectionFormCard(),
                ],
              ),
            ),
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6C6C70),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSavedProfilesCard() {
    return Column(
      children: _savedProfiles.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.router_rounded, color: Color(0xFF007AFF), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.label,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Color(0xFF1C1C1E)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (p.rolePreference != LoginRolePreference.auto) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: p.rolePreference == LoginRolePreference.technician
                                  ? const Color(0xFF007AFF).withValues(alpha: 0.1)
                                  : const Color(0xFF34C759).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.rolePreference.label,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: p.rolePreference == LoginRolePreference.technician
                                    ? const Color(0xFF007AFF)
                                    : const Color(0xFF34C759),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.username}@${p.host}:${p.port}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF8E8E93), fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Hapus',
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF8E8E93), size: 18),
                onPressed: _isConnecting ? null : () => _deleteProfile(p),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isConnecting ? null : () => _connectAndSave(p),
                child: const Text('Hubungkan', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickFillChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 0.6),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF007AFF), fontFamily: 'monospace'),
        ),
      ),
    );
  }

  Widget _buildConnectionFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LABEL INPUT
          _buildMinimalField(
            controller: _labelController,
            label: 'Nama / Label Router',
            placeholder: 'Misal: Router Distribusi Core',
            icon: Icons.label_outline_rounded,
          ),
          const SizedBox(height: 12),

          // HOST & PORT ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildMinimalField(
                  controller: _ipController,
                  label: 'IP / Host Router',
                  placeholder: '192.168.88.1',
                  icon: Icons.language_rounded,
                  isMonospace: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildMinimalField(
                  controller: _portController,
                  label: 'Port API',
                  placeholder: '8777',
                  icon: Icons.tag_rounded,
                  keyboardType: TextInputType.number,
                  isMonospace: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // QUICK FILL PRESETS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildQuickFillChip('192.168.88.1', () => setState(() => _ipController.text = '192.168.88.1')),
                const SizedBox(width: 6),
                _buildQuickFillChip('Port 8777', () => setState(() => _portController.text = '8777')),
                const SizedBox(width: 6),
                _buildQuickFillChip('Port 8728', () => setState(() => _portController.text = '8728')),
                const SizedBox(width: 6),
                _buildQuickFillChip('User admin', () => setState(() => _userController.text = 'admin')),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // USERNAME
          _buildMinimalField(
            controller: _userController,
            label: 'Username',
            placeholder: 'admin',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 12),

          // PASSWORD
          _buildMinimalField(
            controller: _passController,
            label: 'Password',
            placeholder: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePass,
            suffix: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: const Color(0xFF8E8E93),
                size: 18,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          const SizedBox(height: 12),

          // ROLE PREFERENCE SELECTOR
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mode Masuk Aplikasi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6C6C70),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedRolePreference == LoginRolePreference.technician
                          ? Icons.admin_panel_settings_outlined
                          : (_selectedRolePreference == LoginRolePreference.user
                              ? Icons.person_outline_rounded
                              : Icons.auto_mode_rounded),
                      size: 18,
                      color: _selectedRolePreference == LoginRolePreference.technician
                          ? const Color(0xFF007AFF)
                          : (_selectedRolePreference == LoginRolePreference.user
                              ? const Color(0xFF34C759)
                              : const Color(0xFF8E8E93)),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<LoginRolePreference>(
                          isExpanded: true,
                          isDense: true,
                          value: _selectedRolePreference,
                          icon: const Icon(Icons.unfold_more_rounded, size: 18, color: Color(0xFF8E8E93)),
                          items: LoginRolePreference.values.map((pref) {
                            return DropdownMenuItem<LoginRolePreference>(
                              value: pref,
                              child: Text(
                                pref.label,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedRolePreference = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // CONNECT BUTTON (Solid iOS Blue)
          SizedBox(
            height: 44,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: _isConnecting ? const Color(0xFF8E8E93) : const Color(0xFF007AFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isConnecting ? null : _submitNewConnection,
              child: _isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Hubungkan & Simpan',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    IconData? icon,
    bool obscureText = false,
    bool isMonospace = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6C6C70),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 14,
              fontFamily: isMonospace ? 'monospace' : null,
              color: const Color(0xFF1C1C1E),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: placeholder,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFC7C7CC)),
              prefixIcon: icon != null
                  ? Icon(icon, size: 18, color: const Color(0xFF8E8E93))
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 40, maxWidth: 40, minHeight: 44, maxHeight: 44),
              suffixIcon: suffix,
              suffixIconConstraints: const BoxConstraints(minWidth: 40, maxWidth: 40, minHeight: 44, maxHeight: 44),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: icon == null ? 12 : 0,
                vertical: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
