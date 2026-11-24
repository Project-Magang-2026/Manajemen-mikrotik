import 'package:flutter/material.dart';
import '../services/mikrotik_service.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.terminal_rounded,
                    size: 36,
                    color: Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Pocket Winbox',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1E),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seluruh modul fitur Winbox telah dikosongkan.\nSiap untuk dibangun ulang dari awal secara modular.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8E8E93),
                    height: 1.4,
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
