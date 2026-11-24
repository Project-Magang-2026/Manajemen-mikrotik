import 'package:flutter/material.dart';
import '../services/mikrotik_service.dart';
import 'winbox_dialogs.dart';

class WinboxItemInspector {
  static void show({
    required BuildContext context,
    required Map<String, String> item,
    required String basePath,
    required MikroTikService service,
    required VoidCallback onRefresh,
    required Function(String, {bool isError}) showSnack,
  }) {
    final id = item['.id'];
    final name = item['name'] ?? item['address'] ?? item['dst-address'] ?? item['chain'] ?? 'Detail Item';
    final disabled = item['disabled'] == 'true';

    // Editable controllers map
    final controllers = <String, TextEditingController>{};
    for (final entry in item.entries) {
      if (!entry.key.startsWith('.')) {
        controllers[entry.key] = TextEditingController(text: entry.value);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          expand: false,
          builder: (context, scrollCtrl) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Winbox Grab & Title
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFD1D1D6), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        basePath,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF007AFF), fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1C1C1E)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // WINBOX ACTION BUTTONS BAR (OK, Cancel, Apply, Remove, Enable/Disable)
                Row(
                  children: [
                    // Apply Button
                    if (id != null)
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF007AFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () async {
                            final updatedProps = <String, String>{};
                            controllers.forEach((k, v) {
                              final currentVal = v.text.trim();
                              final originalVal = (item[k] ?? '').trim();
                              if (currentVal != originalVal) {
                                updatedProps[k] = currentVal;
                              }
                            });

                            if (updatedProps.isEmpty) {
                              showSnack('Tidak ada perubahan konfigurasi yang dilakukan.');
                              return;
                            }

                            final changesSummary = updatedProps.entries.map((e) {
                              final oldV = item[e.key] ?? '(kosong)';
                              return '• ${e.key}: "$oldV" ➔ "${e.value}"';
                            }).join('\n');

                            final confirm = await WinboxDialogs.showConfirmActionDialog(
                              context: context,
                              title: 'Konfirmasi Perubahan Konfigurasi',
                              message: 'Apakah Anda sudah yakin ingin menerapkan perubahan konfigurasi berikut ke MikroTik?\n\n$changesSummary',
                              confirmLabel: 'Yakin & Terapkan',
                              confirmColor: const Color(0xFF007AFF),
                            );

                            if (!confirm) return;

                            // Tutup sheet terlebih dahulu agar notifikasi hijau langsung terlihat di layar
                            Navigator.pop(ctx);

                            try {
                              await service.setItemProperties(basePath, id, updatedProps);
                              showSnack('Perubahan konfigurasi untuk "$name" berhasil diterapkan!');
                              onRefresh();
                            } catch (e) {
                              showSnack('Gagal: $e', isError: true);
                            }
                          },
                          child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    const SizedBox(width: 6),
                    // Enable/Disable
                    if (id != null && item.containsKey('disabled'))
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: disabled ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                            foregroundColor: disabled ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () async {
                            final willEnable = disabled;
                            final actionText = willEnable ? 'mengaktifkan (enable)' : 'menonaktifkan (disable)';

                            final confirm = await WinboxDialogs.showConfirmActionDialog(
                              context: context,
                              title: 'Konfirmasi',
                              message: 'Apakah Anda yakin ingin $actionText "$name" ($basePath)?',
                              confirmLabel: willEnable ? 'Yakin (Enable)' : 'Yakin (Disable)',
                              confirmColor: willEnable ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                            );

                            if (!confirm) return;

                            Navigator.pop(ctx);
                            try {
                              final cmd = willEnable ? '$basePath/enable' : '$basePath/disable';
                              await service.executePath(cmd, params: {'.id': id});
                              showSnack(willEnable ? 'Item "$name" diaktifkan.' : 'Item "$name" dinonaktifkan.');
                              onRefresh();
                            } catch (e) {
                              showSnack('Gagal: $e', isError: true);
                            }
                          },
                          child: Text(disabled ? 'Enable' : 'Disable', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    const SizedBox(width: 6),
                    // Remove Button
                    if (id != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEBEE),
                          foregroundColor: const Color(0xFFD32F2F),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () async {
                          final confirm = await WinboxDialogs.showConfirmActionDialog(
                            context: context,
                            title: 'Hapus Item (Winbox Remove)?',
                            message: 'Apakah Anda yakin ingin menghapus "$name" ($basePath) secara permanen dari router?',
                            confirmLabel: 'Hapus Permanen',
                            isDestructive: true,
                          );

                          if (!confirm) return;

                          Navigator.pop(ctx);
                          try {
                            await service.executePath('$basePath/remove', params: {'.id': id});
                            showSnack('Item "$name" berhasil dihapus.');
                            onRefresh();
                          } catch (e) {
                            showSnack('Gagal: $e', isError: true);
                          }
                        },
                        child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFE5E5EA)),

                // ALL WINBOX PROPERTIES (Inspector List)
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    children: item.entries.map((e) {
                      final isInternal = e.key.startsWith('.');
                      final ctrl = controllers[e.key];
                      final valLower = (ctrl?.text ?? e.value).trim().toLowerCase();
                      final isBoolean = !isInternal && (valLower == 'true' || valLower == 'false' || valLower == 'yes' || valLower == 'no');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 130,
                              child: Text(
                                e.key,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6C6C70)),
                              ),
                            ),
                            Expanded(
                              child: isInternal || ctrl == null
                                  ? SelectableText(
                                      e.value,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93), fontFamily: 'monospace'),
                                    )
                                  : isBoolean
                                      ? Row(
                                          children: [
                                            Switch.adaptive(
                                              value: valLower == 'true' || valLower == 'yes',
                                              activeColor: const Color(0xFF34C759),
                                              onChanged: (newVal) {
                                                setSheetState(() {
                                                  if (valLower == 'yes' || valLower == 'no') {
                                                    ctrl.text = newVal ? 'yes' : 'no';
                                                  } else {
                                                    ctrl.text = newVal ? 'true' : 'false';
                                                  }
                                                });
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (valLower == 'true' || valLower == 'yes')
                                                    ? const Color(0xFF34C759).withValues(alpha: 0.12)
                                                    : const Color(0xFFFF3B30).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                ctrl.text,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'monospace',
                                                  color: (valLower == 'true' || valLower == 'yes')
                                                      ? const Color(0xFF34C759)
                                                      : const Color(0xFFFF3B30),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2F2F7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: TextField(
                                            controller: ctrl,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: const Color(0xFF1C1C1E),
                                              fontFamily: e.key.contains('address') || e.key.contains('mac') ? 'monospace' : null,
                                            ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                            ),
                                          ),
                                        ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
