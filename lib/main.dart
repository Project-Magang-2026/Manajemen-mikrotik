import 'package:flutter/material.dart';
import 'services/mikrotik_service.dart';
import 'services/profile_storage_service.dart';
import 'screens/profile_list_screen.dart';
import 'screens/router_dashboard_screen.dart';

void main() {
  runApp(const MikroTikIspApp());
}

class MikroTikIspApp extends StatelessWidget {
  const MikroTikIspApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MikroTik Router',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF),
          surface: Colors.white,
          onSurface: Color(0xFF1C1C1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF2F2F7),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
            letterSpacing: -0.3,
          ),
          iconTheme: IconThemeData(color: Color(0xFF007AFF)),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE5E5EA),
          thickness: 0.5,
          space: 1,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titleTextStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF2F2F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFC7C7CC)),
        ),
      ),
      home: const AutoLoginGate(),
    );
  }
}

class AutoLoginGate extends StatefulWidget {
  const AutoLoginGate({super.key});

  @override
  State<AutoLoginGate> createState() => _AutoLoginGateState();
}

class _AutoLoginGateState extends State<AutoLoginGate> {
  final _storage = ProfileStorageService();

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final activeProfile = await _storage.getActiveProfile();
    if (activeProfile == null) {
      _goToProfileList();
      return;
    }

    try {
      final service = MikroTikService(activeProfile);
      final data = await service.fetchDashboardSummary();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RouterDashboardScreen(
            profile: activeProfile,
            initialData: data,
          ),
        ),
      );
    } catch (_) {
      _goToProfileList();
    }
  }

  void _goToProfileList() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfileListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF2F2F7),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF007AFF),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Menghubungkan ke router...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF8E8E93),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
