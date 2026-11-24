import 'package:flutter/material.dart';
import 'services/profile_storage_service.dart';
import 'screens/profile_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProfileStorageService().setActiveProfileId(null);
  runApp(const MikroTikIspApp());
}

class MikroTikIspApp extends StatefulWidget {
  const MikroTikIspApp({super.key});

  @override
  State<MikroTikIspApp> createState() => _MikroTikIspAppState();
}

class _MikroTikIspAppState extends State<MikroTikIspApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      ProfileStorageService().setActiveProfileId(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Winbox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0071E3),
          secondary: Color(0xFF34C759),
          surface: Colors.white,
          onSurface: Color(0xFF1D1D1F),
          error: Color(0xFFFF3B30),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F7),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1D1D1F),
            letterSpacing: -0.4,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0071E3)),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE8E8ED),
          thickness: 0.5,
          space: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          titleTextStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1D1D1F),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE8E8ED), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF0071E3), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintStyle:
              const TextStyle(color: Color(0xFFAEAEB2), fontSize: 14),
        ),
      ),
      home: const ProfileListScreen(),
    );
  }
}