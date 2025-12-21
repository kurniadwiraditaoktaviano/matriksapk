// File: ProfileScreen.dart (tanpa tombol di AppBar dan tanpa tombol kembali)

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'DeviceIdHelper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _universityController = TextEditingController();
  bool _isLoading = false;
  bool _isEditing = false;
  String? _currentName;
  String? _currentUniversity;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load data berdasarkan ID 'user_hp_saya'
  Future<void> _loadData() async {
    try {
      final myId = await DeviceIdHelper.getDeviceId();
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', myId)
          .maybeSingle();
      
      if (data != null && mounted) {
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _universityController.text = data['university'] ?? '';
          _currentName = data['full_name'];
          _currentUniversity = data['university'];
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
      final myId = await DeviceIdHelper.getDeviceId();
      // Langsung simpan ke tabel publik
      await Supabase.instance.client.from('profiles').upsert({
        'id': myId, // Kunci utama kita
        'full_name': _nameController.text.trim(),
        'university': _universityController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _currentName = _nameController.text.trim();
          _currentUniversity = _universityController.text.trim();
          _isEditing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil disimpan!'), 
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'), 
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hapus data profil
  Future<void> _deleteProfile() async {
    if (_currentName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data profil untuk dihapus!')),
      );
      return;
    }

    // Konfirmasi sebelum hapus
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Profil'),
        content: const Text('Apakah Anda yakin ingin menghapus profil ini? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('HAPUS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      final myId = await DeviceIdHelper.getDeviceId();
      await Supabase.instance.client
          .from('profiles')
          .delete()
          .eq('id', myId);

      if (mounted) {
        setState(() {
          _nameController.clear();
          _universityController.clear();
          _currentName = null;
          _currentUniversity = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil dihapus!'), 
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: $e'), 
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Tombol edit untuk mengaktifkan mode editing
  void _enableEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  // Batalkan editing
  void _cancelEditing() {
    setState(() {
      _isEditing = false;
      _nameController.text = _currentName ?? '';
      _universityController.text = _currentUniversity ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
        // TOMBOL DI APPBAR TELAH DIHAPUS SESUAI PERMINTAAN
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header dengan avatar
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF6A11CB),
                        child: Icon(
                          Icons.person,
                          size: 50,
                          // ignore: deprecated_member_use
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      if (_isEditing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _currentName?.isNotEmpty == true ? _currentName! : 'Belum ada nama',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _currentName?.isNotEmpty == true 
                          ? const Color(0xFF1A1A1A) 
                          : Colors.grey,
                    ),
                  ),
                  if (_currentUniversity?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _currentUniversity!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

            // Status info
            if (!_isEditing && _currentName != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                  // ignore: deprecated_member_use
                  border: Border.all(color: const Color(0xFF6A11CB).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF6A11CB),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tekan tombol edit untuk mengubah profil, atau tombol hapus untuk menghapus.',
                        style: TextStyle(
                          color: const Color(0xFF666666),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (!_isEditing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  // ignore: deprecated_member_use
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.person_add,
                      color: Colors.orange,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Silakan isi data profil Anda untuk menyimpan.',
                        style: TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 30),

            // Form input (hanya muncul saat editing atau tidak ada data)
            if (_isEditing || _currentName == null) ...[
              const Text(
                'Informasi Profil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 20),

              // Nama Lengkap
              TextField(
                controller: _nameController,
                enabled: _isEditing || _currentName == null,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap *',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                  hintText: 'Masukkan nama lengkap',
                ),
              ),
              const SizedBox(height: 20),

              // Kampus
              TextField(
                controller: _universityController,
                enabled: _isEditing || _currentName == null,
                decoration: const InputDecoration(
                  labelText: 'Kampus / Institusi',
                  prefixIcon: Icon(Icons.school),
                  border: OutlineInputBorder(),
                  hintText: 'Opsional',
                ),
              ),
              const SizedBox(height: 30),

              // Tombol action
              if (_isEditing || _currentName == null)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6A11CB),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('MENYIMPAN...'),
                                ],
                              )
                            : const Text('SIMPAN PROFIL'),
                      ),
                    ),
                  ],
                ),

              if (_isEditing)
                const SizedBox(height: 12),

              if (_isEditing)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _cancelEditing,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: const Text(
                          'BATAL',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
            ],

            // Tombol utama jika tidak sedang edit
            if (!_isEditing && _currentName != null) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _enableEditing,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A11CB),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('EDIT PROFIL'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _deleteProfile,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                      ),
                      child: const Text(
                        'HAPUS',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // TOMBOL "KEMBALI KE KALKULATOR" TELAH DIHAPUS SESUAI PERMINTAAN
            // (Bagian ini telah dihapus sepenuhnya)
          ],
        ),
      ),
    );
  }
}
