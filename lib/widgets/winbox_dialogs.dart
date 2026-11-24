import 'package:flutter/material.dart';
import '../models/router_models.dart';
import '../services/mikrotik_service.dart';

class WinboxDialogs {
  static Future<bool> showConfirmActionDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Yakin',
    Color confirmColor = const Color(0xFF007AFF),
    bool isDestructive = false,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: Color(0xFF1C1C1E)),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF3C3C43), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? const Color(0xFFFF3B30) : confirmColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  static Widget buildDialogField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    bool isMonospace = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6C6C70)),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontSize: 13.5,
              fontFamily: isMonospace ? 'monospace' : null,
              color: const Color(0xFF1C1C1E),
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: placeholder,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFC7C7CC)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            ),
          ),
        ),
      ],
    );
  }

  static void showAddIpDialog({
    required BuildContext context,
    required MikroTikService service,
    required List<Map<String, String>> interfaces,
    required VoidCallback onSuccess,
    required Function(String, {bool isError}) showSnack,
  }) {
    final ipCtrl = TextEditingController();
    String selectedIface = interfaces.isNotEmpty ? (interfaces.first['name'] ?? 'ether1') : 'ether1';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Tambah IP Address'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildDialogField(controller: ipCtrl, label: 'IP Address / Subnet (CIDR)', placeholder: '192.168.10.1/24'),
              const SizedBox(height: 12),
              const Text('Interface', style: TextStyle(fontSize: 12, color: Color(0xFF6C6C70))),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(8)),
                child: DropdownButton<String>(
                  isExpanded: true,
                  underline: const SizedBox(),
                  value: selectedIface,
                  items: interfaces.map((i) {
                    final name = i['name'] ?? 'ether1';
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedIface = v);
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(
              onPressed: () async {
                final addr = ipCtrl.text.trim();
                if (addr.isEmpty) return;

                final confirm = await showConfirmActionDialog(
                  context: context,
                  title: 'Konfirmasi Tambah IP Address',
                  message: 'Apakah Anda sudah yakin ingin menambahkan IP Address "$addr" pada interface "$selectedIface"?',
                  confirmLabel: 'Yakin & Tambah',
                );
                if (!confirm) return;

                Navigator.pop(ctx);
                try {
                  await service.addIpAddress(address: addr, interface: selectedIface);
                  showSnack('IP $addr berhasil ditambahkan.');
                  onSuccess();
                } catch (e) {
                  showSnack('Gagal: $e', isError: true);
                }
              },
              child: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static void showAddRouteDialog({
    required BuildContext context,
    required MikroTikService service,
    required VoidCallback onSuccess,
    required Function(String, {bool isError}) showSnack,
  }) {
    final dstCtrl = TextEditingController(text: '0.0.0.0/0');
    final gwCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Tambah Static Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogField(controller: dstCtrl, label: 'Dst. Address', placeholder: '0.0.0.0/0'),
            const SizedBox(height: 10),
            buildDialogField(controller: gwCtrl, label: 'Gateway IP / Interface', placeholder: '192.168.1.1'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final dst = dstCtrl.text.trim();
              final gw = gwCtrl.text.trim();
              if (gw.isEmpty) return;

              final confirm = await showConfirmActionDialog(
                context: context,
                title: 'Konfirmasi Tambah Route',
                message: 'Apakah Anda sudah yakin ingin menambahkan Static Route ke "$dst" via "$gw"?',
                confirmLabel: 'Yakin & Tambah',
              );
              if (!confirm) return;

              Navigator.pop(ctx);
              try {
                await service.addRoute(dstAddress: dst, gateway: gw);
                showSnack('Route $dst via $gw berhasil ditambahkan.');
                onSuccess();
              } catch (e) {
                showSnack('Gagal: $e', isError: true);
              }
            },
            child: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showAddQueueDialog({
    required BuildContext context,
    required MikroTikService service,
    required VoidCallback onSuccess,
    required Function(String, {bool isError}) showSnack,
  }) {
    final nameCtrl = TextEditingController(text: 'Limit-User');
    final targetCtrl = TextEditingController(text: '192.168.88.');
    final limitCtrl = TextEditingController(text: '5M/10M');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Tambah Simple Queue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogField(controller: nameCtrl, label: 'Nama Rule', placeholder: 'User-1'),
            const SizedBox(height: 10),
            buildDialogField(controller: targetCtrl, label: 'Target IP / Subnet', placeholder: '192.168.88.50/32'),
            const SizedBox(height: 10),
            buildDialogField(controller: limitCtrl, label: 'Max Limit (Upload/Download)', placeholder: '5M/10M'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || targetCtrl.text.isEmpty) return;

              final confirm = await showConfirmActionDialog(
                context: context,
                title: 'Konfirmasi Tambah Simple Queue',
                message: 'Apakah Anda sudah yakin ingin menambahkan Simple Queue "${nameCtrl.text.trim()}" untuk target "${targetCtrl.text.trim()}" (Limit: ${limitCtrl.text.trim()})?',
                confirmLabel: 'Yakin & Tambah',
              );
              if (!confirm) return;

              Navigator.pop(ctx);
              try {
                await service.addSimpleQueue(
                  name: nameCtrl.text.trim(),
                  target: targetCtrl.text.trim(),
                  maxLimit: limitCtrl.text.trim(),
                );
                showSnack('Queue ${nameCtrl.text} berhasil ditambahkan.');
                onSuccess();
              } catch (e) {
                showSnack('Gagal: $e', isError: true);
              }
            },
            child: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showAddPppSecretDialog({
    required BuildContext context,
    required MikroTikService service,
    required VoidCallback onSuccess,
    required Function(String, {bool isError}) showSnack,
  }) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final profileCtrl = TextEditingController(text: 'default');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Tambah User PPPoE / Secret'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogField(controller: userCtrl, label: 'Username', placeholder: 'pelanggan01'),
            const SizedBox(height: 10),
            buildDialogField(controller: passCtrl, label: 'Password', placeholder: 'sandi123'),
            const SizedBox(height: 10),
            buildDialogField(controller: profileCtrl, label: 'Profile PPP', placeholder: 'default'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              if (userCtrl.text.isEmpty) return;

              final confirm = await showConfirmActionDialog(
                context: context,
                title: 'Konfirmasi Tambah Akun PPP',
                message: 'Apakah Anda sudah yakin ingin menambahkan akun PPP Secret "${userCtrl.text.trim()}"?',
                confirmLabel: 'Yakin & Tambah',
              );
              if (!confirm) return;

              Navigator.pop(ctx);
              try {
                await service.addPppSecret(
                  name: userCtrl.text.trim(),
                  password: passCtrl.text,
                  profile: profileCtrl.text.trim().isEmpty ? 'default' : profileCtrl.text.trim(),
                );
                showSnack('Secret ${userCtrl.text} ditambahkan.');
                onSuccess();
              } catch (e) {
                showSnack('Gagal: $e', isError: true);
              }
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showGenericAddDialog({
    required BuildContext context,
    required MikroTikService service,
    required String basePath,
    required VoidCallback onSuccess,
    required Function(String, {bool isError}) showSnack,
    bool canManageUsers = true,
  }) {
    if (basePath.contains('/user') && !canManageUsers) {
      showSnack('Perubahan pada menu /user membutuhkan izin "policy" atau "full".', isError: true);
      return;
    }

    final key1Ctrl = TextEditingController();
    final val1Ctrl = TextEditingController();
    final key2Ctrl = TextEditingController();
    final val2Ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Tambah ke $basePath'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: buildDialogField(controller: key1Ctrl, label: 'Parameter 1', placeholder: 'name')),
                const SizedBox(width: 8),
                Expanded(child: buildDialogField(controller: val1Ctrl, label: 'Nilai 1', placeholder: 'nilai')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: buildDialogField(controller: key2Ctrl, label: 'Parameter 2 (Opsional)', placeholder: 'target')),
                const SizedBox(width: 8),
                Expanded(child: buildDialogField(controller: val2Ctrl, label: 'Nilai 2', placeholder: 'nilai')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              if (key1Ctrl.text.isEmpty || val1Ctrl.text.isEmpty) return;
              final params = <String, String>{key1Ctrl.text.trim(): val1Ctrl.text.trim()};
              if (key2Ctrl.text.isNotEmpty && val2Ctrl.text.isNotEmpty) {
                params[key2Ctrl.text.trim()] = val2Ctrl.text.trim();
              }

              final confirm = await showConfirmActionDialog(
                context: context,
                title: 'Konfirmasi Tambah Item',
                message: 'Apakah Anda sudah yakin ingin menambahkan data konfigurasi baru ini ke $basePath?\n\n${params.entries.map((e) => "• ${e.key}: ${e.value}").join("\n")}',
                confirmLabel: 'Yakin & Tambah',
              );
              if (!confirm) return;

              Navigator.pop(ctx);
              try {
                await service.executePath('$basePath/add', params: params);
                showSnack('Berhasil ditambahkan ke $basePath.');
                onSuccess();
              } catch (e) {
                showSnack('Gagal: $e', isError: true);
              }
            },
            child: const Text('Tambah', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showEditWifiDialog({
    required BuildContext context,
    required MikroTikService service,
    required WifiInterfaceInfo wifi,
    required VoidCallback onSuccess,
    required Function(String, {bool isError}) showSnack,
  }) {
    final ssidCtrl = TextEditingController(text: wifi.ssid);
    final passCtrl = TextEditingController(text: wifi.password);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Atur Wi-Fi (${wifi.name})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildDialogField(controller: ssidCtrl, label: 'Nama Wi-Fi (SSID)', placeholder: 'Wi-Fi'),
            const SizedBox(height: 10),
            buildDialogField(controller: passCtrl, label: 'Password Baru', placeholder: 'Min. 8 karakter'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              final newSsid = ssidCtrl.text.trim();
              final newPass = passCtrl.text;
              if (newSsid.isEmpty) return;

              final confirm = await showConfirmActionDialog(
                context: context,
                title: 'Konfirmasi Ubah Wi-Fi',
                message: 'Apakah Anda sudah yakin ingin menerapkan konfigurasi Wi-Fi baru untuk "${wifi.name}"?\n\n• Nama SSID: $newSsid\n• Password: ${newPass.isEmpty ? "(Tanpa Sandi)" : newPass}',
                confirmLabel: 'Yakin & Terapkan',
              );
              if (!confirm) return;

              Navigator.pop(ctx);
              try {
                await service.updateWifiConfig(
                  wifi: wifi,
                  newSsid: newSsid,
                  newPassword: newPass,
                );
                showSnack('Pengaturan Wi-Fi berhasil diperbarui!');
                onSuccess();
              } catch (e) {
                showSnack('Gagal: $e', isError: true);
              }
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showConfirmRebootDialog({
    required BuildContext context,
    required MikroTikService service,
    required Function(String, {bool isError}) showSnack,
    bool canReboot = true,
  }) {
    if (!canReboot) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Izin Dibatasi'),
          content: const Text('Akun Anda tidak memiliki izin "reboot". Butuh izin reboot/full di RouterOS untuk merestart perangkat ini.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Reboot Router?'),
        content: const Text('Router akan restart dan koneksi terputus beberapa saat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await service.rebootRouter();
                showSnack('Perintah reboot dikirim ke router.');
              } catch (e) {
                showSnack('Gagal reboot: $e', isError: true);
              }
            },
            child: const Text('Reboot', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void showConfirmShutdownDialog({
    required BuildContext context,
    required MikroTikService service,
    required Function(String, {bool isError}) showSnack,
    bool canReboot = true,
  }) {
    if (!canReboot) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Izin Dibatasi'),
          content: const Text('Akun Anda tidak memiliki izin reboot/write. Butuh izin reboot/full di RouterOS untuk mematikan perangkat ini.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Matikan Router (Shutdown)?'),
        content: const Text('Router akan dimatikan secara aman. Daya harus dinyalakan kembali secara manual.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await service.shutdownRouter();
                showSnack('Perintah shutdown dikirim ke router.');
              } catch (e) {
                showSnack('Gagal shutdown: $e', isError: true);
              }
            },
            child: const Text('Shutdown', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
