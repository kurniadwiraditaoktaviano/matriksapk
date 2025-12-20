import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ID Simpel untuk HP ini (Bisa diganti logika lain nanti)
const String myDeviceID = 'user_hp_saya'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load data berdasarkan ID 'user_hp_saya'
  Future<void> _loadData() async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', myDeviceID)
          .maybeSingle();
      
      if (data != null && mounted) {
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _universityController.text = data['university'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Belum ada data: $e');
    }
  }

  // Simpan data ke ID 'user_hp_saya'
  Future<void> _saveData() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama tidak boleh kosong!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Langsung simpan ke tabel publik
      await Supabase.instance.client.from('profiles').upsert({
        'id': myDeviceID, // Kunci utama kita
        'full_name': _nameController.text.trim(),
        'university': _universityController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berhasil disimpan!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Balik ke menu utama
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFF6A11CB),
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Silakan isi nama kamu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.badge)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _universityController,
              decoration: const InputDecoration(labelText: 'Kampus (Opsional)', prefixIcon: Icon(Icons.school)),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveData,
                child: Text(_isLoading ? 'MENYIMPAN...' : 'SIMPAN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}