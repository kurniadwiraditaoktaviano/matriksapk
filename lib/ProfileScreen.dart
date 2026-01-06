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
          SnackBar(
            content: const Text('Profil berhasil disimpan!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
    final confirm = await showDialog<bool>(
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('HAPUS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

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
          SnackBar(
            content: const Text('Profil berhasil dihapus!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Profil Saya',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan avatar
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: isSmallScreen ? 100 : 120,
                          height: isSmallScreen ? 100 : 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6A11CB).withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.person,
                              size: isSmallScreen ? 40 : 50,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: isSmallScreen ? 28 : 32,
                              height: isSmallScreen ? 28 : 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.edit,
                                size: isSmallScreen ? 14 : 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 16 : 24),
                    Text(
                      _currentName?.isNotEmpty == true ? _currentName! : 'Belum ada nama',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 22 : 26,
                        fontWeight: FontWeight.w800,
                        color: _currentName?.isNotEmpty == true 
                            ? const Color(0xFF0F172A) 
                            : const Color(0xFF94A3B8),
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_currentUniversity?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _currentUniversity!,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(height: isSmallScreen ? 24 : 32),
                  ],
                ),
              ),

              // Status info
              if (!_isEditing && _currentName != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withOpacity(0.05),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isSmallScreen ? 36 : 40,
                        height: isSmallScreen ? 36 : 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 18 : 20,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tips',
                              style: TextStyle(
                                color: Color(0xFF0369A1),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tekan tombol edit untuk mengubah profil, atau tombol hapus untuk menghapus.',
                              style: TextStyle(
                                color: const Color(0xFF0C4A6E),
                                fontSize: isSmallScreen ? 12 : 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (!_isEditing)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.05),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: isSmallScreen ? 36 : 40,
                        height: isSmallScreen ? 36 : 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 18 : 20,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selamat Datang!',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Silakan isi data profil Anda untuk menyimpan.',
                              style: TextStyle(
                                color: const Color(0xFF78350F),
                                fontSize: isSmallScreen ? 12 : 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: isSmallScreen ? 24 : 32),

              // Form input (hanya muncul saat editing atau tidak ada data)
              if (_isEditing || _currentName == null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Informasi Profil',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),

                // Nama Lengkap
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: TextField(
                    controller: _nameController,
                    enabled: _isEditing || _currentName == null,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF334155),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap *',
                      labelStyle: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.badge_outlined,
                          color: const Color(0xFF6A11CB),
                          size: isSmallScreen ? 20 : 22,
                        ),
                      ),
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
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: isSmallScreen ? 14 : 16,
                      ),
                      hintText: 'Masukkan nama lengkap',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),

                // Kampus
                Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  child: TextField(
                    controller: _universityController,
                    enabled: _isEditing || _currentName == null,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 15,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF334155),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Kampus / Institusi',
                      labelStyle: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.school_outlined,
                          color: const Color(0xFF6A11CB),
                          size: isSmallScreen ? 20 : 22,
                        ),
                      ),
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
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: isSmallScreen ? 14 : 16,
                      ),
                      hintText: 'Opsional',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),

                // Tombol action
                if (_isEditing || _currentName == null)
                  Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: isSmallScreen ? 48 : 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              // ignore: deprecated_member_use
                              color: const Color(0xFF6A11CB).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveData,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: _isLoading
                              ? Row(
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
                                    const SizedBox(width: 12),
                                    Text(
                                      'MENYIMPAN...',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: isSmallScreen ? 14 : 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, color: Colors.white, size: isSmallScreen ? 18 : 20),
                                    SizedBox(width: isSmallScreen ? 8 : 10),
                                    Text(
                                      'SIMPAN PROFIL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: isSmallScreen ? 14 : 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      if (_isEditing) const SizedBox(height: 12),

                      if (_isEditing)
                        SizedBox(
                          width: double.infinity,
                          height: isSmallScreen ? 48 : 56,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _cancelEditing,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(
                                color: Color(0xFFCBD5E1),
                                width: 1.5,
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: Text(
                              'BATAL',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isSmallScreen ? 14 : 15,
                                color: const Color(0xFF64748B),
                              ),
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
                      child: Container(
                        height: isSmallScreen ? 48 : 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6A11CB).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _enableEditing,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.edit_rounded, color: Colors.white, size: isSmallScreen ? 18 : 20),
                              SizedBox(width: isSmallScreen ? 8 : 10),
                              Text(
                                'EDIT PROFIL',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isSmallScreen ? 14 : 15,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Expanded(
                      child: Container(
                        height: isSmallScreen ? 48 : 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF87171),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF87171).withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: OutlinedButton(
                          onPressed: _deleteProfile,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide.none,
                            backgroundColor: Colors.white,
                          ),
                          child: Text(
                            'HAPUS',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isSmallScreen ? 14 : 15,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: isSmallScreen ? 32 : 40),

              // Footer
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: const Color(0xFF64748B),
                      size: isSmallScreen ? 20 : 24,
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Text(
                      'Data Aman & Terenkripsi',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 4),
                    Text(
                      'Profil Anda disimpan dengan aman di server',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: const Color(0xFF64748B).withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
