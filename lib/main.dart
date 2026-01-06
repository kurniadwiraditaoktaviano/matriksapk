import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'MatrixCalculatorScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hanya Inisialisasi. TIDAK ADA proses login-loginan.
  await Supabase.initialize(
    url: 'https://emkmpjsajvmicksefvga.supabase.co',
    // WARNING: This key looks like a Publishable Key but has a non-standard prefix.
    // Standard keys start with 'eyJ...'. If connection fails, check your Supabase Project Settings > API.
    anonKey: 'sb_publishable_M8SQ-x4xtBSdsrOYx4XSpQ_0G040m15',
  );

  runApp(const MatrixApp());
}

class MatrixApp extends StatelessWidget {
  const MatrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Matrix Solver Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A11CB),
          brightness: Brightness.light,
          primary: const Color(0xFF6A11CB),
          secondary: const Color(0xFF2575FC),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
        fontFamily: 'Inter',
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black12,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
        // PERBAIKAN: Hapus cardTheme atau gunakan CardThemeData
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A11CB),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            shadowColor: const Color(0xFF6A11CB).withOpacity(0.3),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            side: const BorderSide(color: Color(0xFF6A11CB), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Color(0xFF6A11CB),
            ),
          ),
        ),
        sliderTheme: SliderThemeData(
          trackHeight: 6,
          thumbShape: RoundSliderThumbShape(
            enabledThumbRadius: 12,
            disabledThumbRadius: 8,
            elevation: 4,
          ),
          overlayShape: RoundSliderOverlayShape(
            overlayRadius: 20,
          ),
          activeTrackColor: const Color(0xFF6A11CB),
          inactiveTrackColor: const Color(0xFFE2E8F0),
          thumbColor: const Color(0xFF6A11CB),
        ),
        // PERBAIKAN: Hapus tabBarTheme atau gunakan TabBarThemeData
      ),
      home: const MatrixCalculatorScreen(),
    );
  }
}