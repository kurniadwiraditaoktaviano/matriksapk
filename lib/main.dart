import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'MatrixCalculatorScreen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hanya Inisialisasi. TIDAK ADA proses login-loginan.
  await Supabase.initialize(
    url: 'https://emkmpjsajvmicksefvga.supabase.co',
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
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
        fontFamily: 'Inter',
        // ... (Kode tema ke bawah SAMA PERSIS seperti sebelumnya) ...
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black12,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
        ),
        cardTheme: CardThemeData(elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), color: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF6A11CB), width: 2)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A11CB), foregroundColor: Colors.white, elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            side: const BorderSide(color: Color(0xFF6A11CB), width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF6A11CB)),
          ),
        ),
      ),
      home: const MatrixCalculatorScreen(),
    );
  }
}