import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseManager {
  // --- KONFIGURASI SUPABASE ---
  // PENTING: Ganti URL dan KEY ini dengan project Anda sendiri!
  static const String supabaseUrl = 'https://ujfkbeysiyuazuwmiqln.supabase.co';
  static const String supabaseAnonKey = 'PASTE_KEY_HERE'; // Copy the "anon public" key here

  static final SupabaseManager _instance = SupabaseManager._internal();

  factory SupabaseManager() {
    return _instance;
  }

  SupabaseManager._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (supabaseUrl == 'YOUR_SUPABASE_URL_HERE') {
      print('Supabase belum dikonfigurasi. History tidak akan aktif.');
      return;
    }
    
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
    } catch (e) {
      print('Gagal inisialisasi Supabase: $e');
    }
  }

  Future<void> saveCalculation({
    required String matrixA,
    required String matrixB,
    required String operation,
    required String result,
  }) async {
    if (!_isInitialized) return;

    try {
      await Supabase.instance.client.from('calculation_history').insert({
        'matrix_a': matrixA,
        'matrix_b': matrixB,
        'operation': operation,
        'result': result,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Gagal menyimpan history: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    if (!_isInitialized) return [];

    try {
      final response = await Supabase.instance.client
          .from('calculation_history')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Gagal mengambil history: $e');
      return [];
    }
  }
}
