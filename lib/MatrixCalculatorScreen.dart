import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'MatrixUtils.dart';
import 'ProfileScreen.dart';
import 'DeviceIdHelper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MatrixCalculatorScreen extends StatefulWidget {
  const MatrixCalculatorScreen({super.key});

  @override
  State<MatrixCalculatorScreen> createState() => _MatrixCalculatorScreenState();
}

class _MatrixCalculatorScreenState extends State<MatrixCalculatorScreen>
    with SingleTickerProviderStateMixin {
  // --- STATE VARIABLES ---
  int rows = 4, cols = 4;
  static const int maxDim = 8;
  static const int minDim = 1;

  late List<List<TextEditingController>> controllers;
  int precision = 3;
  bool isCalculating = false;
  double _displayScale = 1.0;

  List<double> solution = [];
  String lastOperationLabel = '';
  String operationStatus = 'Ready';

  List<List<List<double>>> obeSnapshots = [];
  List<String> obeDescriptions = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Responsive constants
  double get _contentPadding => 16.0;
  double get _buttonHeight => 56.0;
  double get _cardMargin => 12.0;

  @override
  void initState() {
    super.initState();
    _initControllers();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var row in controllers) {
      for (var c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _initControllers() {
    controllers = List.generate(
      rows,
      (i) => List.generate(cols + 1, (j) => TextEditingController(text: j == i ? '1' : '0')),
    );
  }

  void _resize(int newRows, int newCols) {
    final oldR = controllers.length;
    final oldC = controllers.isNotEmpty ? controllers[0].length : 0;
    List<List<TextEditingController>> next = List.generate(
      newRows,
      (i) => List.generate(
        newCols + 1,
        (j) => TextEditingController(
          text: i < oldR && j < oldC ? controllers[i][j].text : '0',
        ),
      ),
    );

    for (int i = 0; i < oldR; i++) {
      for (int j = 0; j < oldC; j++) {
        if (i >= newRows || j >= newCols + 1) {
          controllers[i][j].dispose();
        }
      }
    }

    setState(() {
      rows = newRows;
      cols = newCols;
      controllers = next;
      solution = [];
      obeSnapshots.clear();
      obeDescriptions.clear();
      operationStatus = 'Matrix resized to $newRows × $newCols';
    });
  }

  List<List<double>> _readAugmentedMatrix() {
    final r = rows;
    final c = cols + 1;
    return List.generate(r, (i) {
      return List.generate(c, (j) {
        final t = controllers[i][j].text.trim();
        if (t.isEmpty) return 0.0;
        if (t.contains('/')) {
          final p = t.split('/');
          if (p.length == 2) {
            final a = double.tryParse(p[0].trim());
            final b = double.tryParse(p[1].trim());
            if (a != null && b != null && b != 0) return a / b;
          }
        }
        return double.tryParse(t.replaceAll(',', '.')) ?? 0.0;
      });
    });
  }

  List<List<double>> _readMatrixAOnly() {
    final aug = _readAugmentedMatrix();
    return aug.map((row) => row.sublist(0, cols)).toList();
  }

  // --- LOGIC MATEMATIKA ---
  Future<void> _onCalculateDet() async {
    if (rows != cols) {
      _showError('Determinant requires square matrix (Rows = Columns)');
      return;
    }
    
    setState(() => isCalculating = true);
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final A = _readMatrixAOnly();
      final det = MatrixOps.determinant(A);

      _showResultDialog(
        title: 'Determinant',
        icon: Icons.functions_rounded,
        iconColor: const Color(0xFF10B981),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'det(A) =',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.1),
                    const Color(0xFF10B981).withOpacity(0.05),
                ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Text(
                det.toStringAsFixed(6),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF065F46),
                  fontFamily: 'Monospace',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(
                  icon: Icons.info_rounded,
                  label: det.abs() < 1e-12 ? 'Singular' : 'Non-singular',
                  color: det.abs() < 1e-12 ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  icon: Icons.grid_4x4_rounded,
                  label: '${rows} × $rows',
                  color: const Color(0xFF3B82F6),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              det.abs() < 1e-12 
                  ? 'Matrix is singular (determinant is zero)'
                  : 'Matrix is invertible',
              style: TextStyle(
                fontSize: 12,
                color: det.abs() < 1e-12 ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
      
      setState(() {
        lastOperationLabel = 'Determinant Calculated';
        operationStatus = 'det(A) = ${det.toStringAsFixed(precision)}';
      });
    } catch (e) {
      _showError('Error calculating determinant: $e');
    } finally {
      setState(() => isCalculating = false);
    }
  }

  Future<void> _onCalculateInverse() async {
    if (rows != cols) {
      _showError('Inverse requires square matrix (Rows = Columns)');
      return;
    }
    
    setState(() => isCalculating = true);
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final A = _readMatrixAOnly();
      final inv = MatrixOps.inverse(A);

      if (inv == null) {
        _showError('Matrix is singular (Determinant = 0), no inverse exists.');
        return;
      }

    _showResultDialog(
      title: 'Matrix Inverse',
      icon: Icons.swap_horizontal_circle_rounded,
      iconColor: const Color(0xFF8B5CF6),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A⁻¹ =',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: inv.asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: i < inv.length - 1 ? 12 : 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: row.asMap().entries.map((cell) {
                          return Container(
                            width: 70,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  const Color(0xFFF8FAFC),
                              ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              cell.value.toStringAsFixed(precision),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Monospace',
                                color: Color(0xFF334155),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5CF6),
                          const Color(0xFF7C3AED),
                      ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _copyMatrixToClipboard(inv),
                      icon: const Icon(Icons.copy_all_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'Copy Matrix',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
      setState(() {
        lastOperationLabel = 'Inverse Calculated';
        operationStatus = 'A⁻¹ computed successfully';
      });
    } catch (e) {
      _showError('Error calculating inverse: $e');
    } finally {
      setState(() => isCalculating = false);
    }
  }

  void _computeRREFAndSolution() {
    final aug = _readAugmentedMatrix();
    final n = rows;
    final m = cols + 1;
    List<List<double>> mat = List.generate(n, (i) => List.from(aug[i]));

    obeSnapshots.clear();
    obeDescriptions.clear();
    _recordOBE(mat, 'Initial Augmented Matrix [A | B]');

    int r = 0;
    for (int c = 0; c < cols && r < n; c++) {
      int sel = r;
      for (int i = r + 1; i < n; i++) {
        if (mat[i][c].abs() > mat[sel][c].abs()) sel = i;
      }
      if (mat[sel][c].abs() < 1e-12) continue;

      if (sel != r) {
        final tmp = mat[sel];
        mat[sel] = mat[r];
        mat[r] = tmp;
        _recordOBE(mat, 'Swap row $sel with row $r');
      }

      final pivot = mat[r][c];
      if (pivot.abs() < 1e-15) continue;
      for (int j = c; j < m; j++) {
        mat[r][j] /= pivot;
      }
      _recordOBE(mat, 'Normalize row $r (pivot at column $c = 1)');

      for (int i = 0; i < n; i++) {
        if (i == r) continue;
        final factor = mat[i][c];
        if (factor.abs() < 1e-12) continue;
        for (int j = c; j < m; j++) {
          mat[i][j] -= factor * mat[r][j];
        }
        _recordOBE(mat, 'Eliminate column $c in row $i');
      }
      r++;
    }

    // Check consistency
    for (int i = 0; i < n; i++) {
      bool allZero = true;
      for (int j = 0; j < cols; j++) {
        if (mat[i][j].abs() > 1e-9) allZero = false;
      }
      if (allZero && mat[i][cols].abs() > 1e-9) {
        setState(() {
          solution = [];
          lastOperationLabel = 'Inconsistent System';
          operationStatus = 'No solution (inconsistent system)';
        });
        return;
      }
    }

    // Try read unique solution
    List<double> sol = List.filled(cols, double.nan);
    bool unique = true;

    for (int c = 0; c < cols; c++) {
      int prow = -1;
      for (int i = 0; i < n; i++) {
        if ((mat[i][c] - 1.0).abs() < 1e-9) {
          bool onlyPivot = true;
          for (int cc = 0; cc < cols; cc++) {
            if (cc != c && mat[i][cc].abs() > 1e-9) onlyPivot = false;
          }
          if (onlyPivot) {
            prow = i;
            break;
          }
        }
      }
      if (prow == -1) {
        unique = false;
        break;
      }
      sol[c] = mat[prow][cols];
    }

    setState(() {
      solution = unique ? sol : [];
      lastOperationLabel = unique ? 'Unique Solution' : 'Parametric Solution';
      operationStatus = unique 
          ? 'System has unique solution' 
          : 'System has infinite solutions';
    });
  }

  void _recordOBE(List<List<double>> mat, String desc) {
    final snap = mat.map((r) => List<double>.from(r)).toList();
    obeSnapshots.add(snap);
    obeDescriptions.add(desc);
  }

  Future<void> _onCalculateSPL() async {
    setState(() {
      isCalculating = true;
      operationStatus = 'Solving system...';
    });
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      _computeRREFAndSolution();
      if (obeSnapshots.isNotEmpty) {
        await _showOBEViewer(0);
      }
    } finally {
      setState(() => isCalculating = false);
    }
  }

  void _clearAll() {
    for (var row in controllers) {
      for (var c in row) {
        c.text = '0';
      }
    }
    setState(() {
      solution = [];
      lastOperationLabel = '';
      operationStatus = 'Matrix cleared';
      obeSnapshots.clear();
      obeDescriptions.clear();
    });
    _showSuccess('Matrix cleared successfully');
  }

  // --- UI COMPONENTS ---

  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    try {
      final myId = await DeviceIdHelper.getDeviceId();
      return await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', myId)
          .maybeSingle();
    } catch (e) {
      return null;
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      centerTitle: true,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isSmallScreen ? 32 : 36,
            height: isSmallScreen ? 32 : 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A11CB).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.grid_on_rounded,
                color: Colors.white,
                size: isSmallScreen ? 16 : 18,
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
          Text(
            isSmallScreen ? 'MATRIX SOLVER' : 'MATRIX SOLVER PRO',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isSmallScreen ? 14 : 16,
              letterSpacing: 0.5,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(right: isSmallScreen ? 8 : 12),
          child: IconButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: Container(
              width: isSmallScreen ? 36 : 40,
              height: isSmallScreen ? 36 : 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: const Color(0xFF475569),
                size: isSmallScreen ? 18 : 20,
              ),
            ),
            tooltip: 'Settings',
          ),
        ),
      ],
      toolbarHeight: isSmallScreen ? 56 : 64,
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.05),
      surfaceTintColor: Colors.white,
      scrolledUnderElevation: 1,
    );
  }

Widget _buildSettingsDrawer() {
    return FutureBuilder(
      future: _fetchUserProfile(),
      builder: (context, snapshot) {

        String displayName = 'Pengguna Baru';
        String displaySub = 'Ketuk untuk isi nama';

        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data as Map<String, dynamic>;
          displayName = data['full_name'] ?? 'Pengguna';
          displaySub = data['university'] ?? 'Matrix Solver Pro';
        }

        return Drawer(
          width: MediaQuery.of(context).size.width * 0.85,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // HEADER DRAWER
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(context); 
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                    setState(() {}); // Refresh setelah kembali
                  },
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6A11CB),
                          const Color(0xFF2575FC),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName, 
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      displaySub,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // MENU LAINNYA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'DISPLAY SETTINGS',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Slider Precision
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.precision_manufacturing_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Decimal Precision',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Set number of decimal places',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 6,
                                        thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius: 12,
                                          disabledThumbRadius: 8,
                                          elevation: 4,
                                        ),
                                        overlayShape: RoundSliderOverlayShape(
                                          overlayRadius: 20,
                                        ),
                                        activeTrackColor: const Color(0xFF8B5CF6),
                                        inactiveTrackColor: const Color(0xFFE2E8F0),
                                        thumbColor: const Color(0xFF8B5CF6),
                                      ),
                                      child: Slider(
                                        value: precision.toDouble(), 
                                        min: 0, 
                                        max: 10, 
                                        divisions: 10, 
                                        onChanged: (val) => setState(() => precision = val.toInt()),
                                        label: '$precision',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '$precision',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '0',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '10',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Slider Scale
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.text_fields_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Display Scale',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Adjust text size',
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 6,
                                        thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius: 12,
                                          disabledThumbRadius: 8,
                                          elevation: 4,
                                        ),
                                        overlayShape: RoundSliderOverlayShape(
                                          overlayRadius: 20,
                                        ),
                                        activeTrackColor: const Color(0xFF10B981),
                                        inactiveTrackColor: const Color(0xFFE2E8F0),
                                        thumbColor: const Color(0xFF10B981),
                                      ),
                                      child: Slider(
                                        value: _displayScale, 
                                        min: 0.8, 
                                        max: 1.2, 
                                        divisions: 4, 
                                        onChanged: (val) => setState(() => _displayScale = val),
                                        label: _getDisplayScaleLabel(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF10B981).withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _getDisplayScaleLabel(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Small',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Large',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Help
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showHelpDialog(),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.help_outline_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Help & Tutorial',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Learn how to use the app',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFFCBD5E1),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // App Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.code_rounded,
                              size: 14,
                              color: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Matrix Solver Pro • v1.0 • Precision: $precision',
                              style: TextStyle(
                                color: const Color(0xFF64748B).withOpacity(0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMatrixInputCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.all(_cardMargin),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6A11CB),
                      const Color(0xFF2575FC),
                  ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.grid_on_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'INPUT MATRIX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter matrix A and vector b for Ax = b',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (solution.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${solution.length} variables',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Dimension Controls
                    _buildDimensionControls(),
                    const SizedBox(height: 24),
                    
                    // Matrix Grid
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildMatrixGrid(),
                    ),
                    const SizedBox(height: 24),
                    
                    // Status Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF8FAFC),
                            const Color(0xFFF1F5F9),
                        ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getStatusColor().withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: _getStatusColor().withOpacity(0.2)),
                            ),
                            child: Center(
                              child: Icon(
                                _getStatusIcon(),
                                color: _getStatusColor(),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  operationStatus,
                                  style: TextStyle(
                                    color: _getStatusColor(),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. WADAH UTAMA (Card)
  Widget _buildDimensionControls() {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.aspect_ratio_rounded,
                  size: isSmallScreen ? 16 : 18,
                  color: const Color(0xFF6A11CB),
                ),
                const SizedBox(width: 8),
                Text(
                  'MATRIX DIMENSIONS',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6A11CB),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Layout responsif untuk mobile
            if (isSmallScreen)
              Column(
                children: [
                  // ROWS control
                  _buildDimensionControl(
                    label: 'ROWS',
                    value: rows,
                    onDecrease: rows > minDim ? () => _resize(rows - 1, cols) : null,
                    onIncrease: rows < maxDim ? () => _resize(rows + 1, cols) : null,
                    isSmallScreen: true,
                  ),
                  const SizedBox(height: 16),
                  // Separator
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(height: 16),
                  // COLUMNS control
                  _buildDimensionControl(
                    label: 'COLUMNS',
                    value: cols,
                    onDecrease: cols > minDim ? () => _resize(rows, cols - 1) : null,
                    onIncrease: cols < maxDim ? () => _resize(rows, cols + 1) : null,
                    isSmallScreen: true,
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // KONTROL ROWS (KIRI)
                  Expanded(
                    child: _buildDimensionControl(
                      label: 'ROWS',
                      value: rows,
                      onDecrease: rows > minDim ? () => _resize(rows - 1, cols) : null,
                      onIncrease: rows < maxDim ? () => _resize(rows + 1, cols) : null,
                      isSmallScreen: false,
                    ),
                  ),
                  
                  // GARIS PEMISAH TENGAH
                  Container(
                    width: 1,
                    height: 40,
                    color: const Color(0xFFF1F5F9),
                  ),

                  // KONTROL COLUMNS (KANAN)
                  Expanded(
                    child: _buildDimensionControl(
                      label: 'COLUMNS',
                      value: cols,
                      onDecrease: cols > minDim ? () => _resize(rows, cols - 1) : null,
                      onIncrease: cols < maxDim ? () => _resize(rows, cols + 1) : null,
                      isSmallScreen: false,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // 2. ITEM KONTROL (Tombol - Angka - Tombol)
  Widget _buildDimensionControl({
    required String label,
    required int value,
    VoidCallback? onDecrease,
    VoidCallback? onIncrease,
    required bool isSmallScreen,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlButton(
              icon: Icons.remove_rounded,
              onPressed: onDecrease,
              isEnabled: onDecrease != null,
              isSmallScreen: isSmallScreen,
            ),
            
            const SizedBox(width: 12), // TAMBAH JARAK DI SINI
            
            // KOTAK ANGKA - PERBESAR
            Container(
              width: isSmallScreen ? 50 : 60, // PERBESAR DARI 28/32
              height: isSmallScreen ? 50 : 60, // TAMBAH TINGGI
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12), // PERBESAR RADIUS
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6A11CB).withOpacity(0.3),
                    blurRadius: 12, // PERBESAR SHADOW
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 24 : 28, // PERBESAR FONT
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 12), // TAMBAH JARAK DI SINI
            
            _buildControlButton(
              icon: Icons.add_rounded,
              onPressed: onIncrease,
              isEnabled: onIncrease != null,
              isSmallScreen: isSmallScreen,
            ),
          ],
        ),
      ],
    );
  }

  // 3. TOMBOL (+ dan -)
  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isEnabled,
    required bool isSmallScreen,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(10),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onPressed,
        child: Container(
          width: isSmallScreen ? 44 : 50, // PERBESAR DARI 32/36
          height: isSmallScreen ? 44 : 50, // PERBESAR DARI 32/36
          decoration: BoxDecoration(
            color: isEnabled
                ? const Color(0xFFF1F5F9)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEnabled
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFF1F5F9),
              width: 2, // PERBESAR BORDER
            ),
            boxShadow: isEnabled ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : [],
          ),
          child: Center(
            child: Icon(
              icon,
              size: isSmallScreen ? 22 : 24, // PERBESAR ICON
              color: isEnabled ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixGrid() {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // PERHITUNGAN LEBAR CELL YANG LEBIH KONSISTEN
    final int totalColumns = cols + 1;
    final double availableWidth = screenWidth - (isSmallScreen ? 60 : 80); // Kurangi padding
    final double minCellWidth = isSmallScreen ? 55 : 65; // PERKECIL dari sebelumnya
    final double maxCellWidth = isSmallScreen ? 70 : 80;
    
    // Hitung lebar per kolom
    final double calculatedWidth = availableWidth / totalColumns;
    final double cellWidth = calculatedWidth.clamp(minCellWidth, maxCellWidth);
    
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== HEADER (x1, x2, x3, →) ==========
            Container(
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 8 : 10,
                horizontal: isSmallScreen ? 12 : 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6A11CB),
                    const Color(0xFF2575FC),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // SPACE UNTUK ROW LABELS (R1, R2, dll)
                  SizedBox(
                    width: isSmallScreen ? 48 : 56, // PERBESAR dari 50/58
                    child: Center(
                      child: Text(
                        'Row',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: isSmallScreen ? 10 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  // HEADER UNTUK KOLOM MATRIKS A (x1, x2, x3, ...)
                  ...List.generate(cols, (j) => SizedBox(
                    width: cellWidth,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 3 : 4,
                          horizontal: isSmallScreen ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: Text(
                          'x${j+1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF6A11CB),
                            fontSize: isSmallScreen ? 11 : 12, // PERKECIL
                          ),
                        ),
                      ),
                    ),
                  )),
                  
                  // HEADER UNTUK KOLOM B (→)
                  SizedBox(
                    width: cellWidth,
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 3 : 4,
                          horizontal: isSmallScreen ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_forward_rounded, // Ganti icon agar lebih jelas
                              size: isSmallScreen ? 10 : 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'b',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: isSmallScreen ? 11 : 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ========== DATA ROWS (R1, R2, R3, R4) ==========
            ...List.generate(rows, (i) => Container(
              padding: EdgeInsets.symmetric(
                vertical: isSmallScreen ? 6 : 8,
                horizontal: isSmallScreen ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                border: i < rows - 1
                  ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))
                  : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ROW LABEL (R1, R2, dll)
                  SizedBox(
                    width: isSmallScreen ? 48 : 56, // PERBESAR dari 50/58
                    child: Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 8,
                          vertical: isSmallScreen ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A11CB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'R${i+1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontSize: isSmallScreen ? 11 : 12, // PERKECIL
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // INPUT FIELDS UNTUK MATRIKS A
                  ...List.generate(cols, (j) => Container(
                    width: cellWidth,
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 2 : 4),
                    child: TextField(
                      controller: controllers[i][j],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14, // PERKECIL
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 10 : 12, // PERKECIL
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF6A11CB),
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[-0-9.,/]+'),
                        ),
                      ],
                    ),
                  )),
                  
                  // INPUT FIELD UNTUK VECTOR B (→)
                  Container(
                    width: cellWidth,
                    padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 2 : 4),
                    child: TextField(
                      controller: controllers[i][cols],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14, // PERKECIL
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                      ),
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 10 : 12, // PERKECIL
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red.shade400),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.red.shade700,
                            width: 1.5,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.red.shade50,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Primary button full width
        SizedBox(
          width: double.infinity,
          child: _buildPrimaryButton(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSecondaryButton(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    return Container(
      height: _buttonHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6A11CB),
            const Color(0xFF2575FC),
        ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A11CB).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isCalculating ? null : _onCalculateSPL,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: isCalculating
              ? [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'SOLVING...',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ]
              : [
                  const Icon(Icons.calculate_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'SOLVE SYSTEM',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return Container(
      height: _buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: OutlinedButton(
        onPressed: _clearAll,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide.none,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.clear_all_rounded, color: Color(0xFF64748B), size: 20),
            SizedBox(width: 8),
            Text(
              'CLEAR MATRIX',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionCard() {
    if (solution.isEmpty && lastOperationLabel.isEmpty) return const SizedBox();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: _cardMargin, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF10B981),
                      const Color(0xFF059669),
                  ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SOLUTIONS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lastOperationLabel,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (solution.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${solution.length} variables',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Tabs Content
              DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    Container(
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(0),
                        ),
                      ),
                      child: TabBar(
                        labelColor: const Color(0xFF10B981),
                        unselectedLabelColor: const Color(0xFF64748B),
                        indicatorColor: const Color(0xFF10B981),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
                        tabs: const [
                          Tab(text: 'SOLUTION'),
                          Tab(text: 'OPERATIONS'),
                          Tab(text: 'ADVANCED'),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 320,
                      child: TabBarView(
                        children: [
                          // Tab 1: Solution
                          _buildSolutionTab(),
                          
                          // Tab 2: Operations
                          _buildOperationsTab(),
                          
                          // Tab 3: Advanced
                          _buildAdvancedTab(),
                        ],
                      ),
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

  Widget _buildSolutionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYSTEM SOLUTION',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          
          if (solution.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFF1F5F9),
                ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_mosaic_rounded,
                      size: 40,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Solution Calculated',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click "Solve System" to find solution for Ax = b',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFECFDF5),
                        const Color(0xFFF0F9FF),
                    ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Solution Vector x:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: List.generate(solution.length, (i) {
                          return Container(
                            width: 100, // Increased from 90 for better visibility
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  const Color(0xFFF8FAFC),
                              ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6A11CB),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'x${i + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  solution[i].toStringAsFixed(precision),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                    fontFamily: 'Monospace',
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF6A11CB),
                              const Color(0xFF2575FC),
                          ],
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
                        child: ElevatedButton.icon(
                          onPressed: _copySolutionCSV,
                          icon: const Icon(Icons.copy_all_rounded, size: 18, color: Colors.white),
                          label: const Text(
                            'Copy Values',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: OutlinedButton.icon(
                          onPressed: () => _showOBEViewer(0),
                          icon: const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF475569)),
                          label: const Text(
                            'View Steps',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOperationsTab() {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    final bool isSquare = rows == cols;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MATRIX OPERATIONS',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            isSquare ? 'Square Matrix ($rows × $rows)' : 'Non-square Matrix',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // Matrix Operations Grid - PERBAIKI LAYOUT
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: isSmallScreen ? 12 : 16,
            crossAxisSpacing: isSmallScreen ? 12 : 16,
            childAspectRatio: 1.2, // PERBAIKI ASPECT RATIO
            padding: EdgeInsets.zero,
            children: [
              _buildOperationCard(
                title: 'Determinant',
                icon: Icons.functions_rounded,
                color: const Color(0xFF10B981),
                enabled: isSquare,
                onTap: _onCalculateDet,
                description: 'det(A)',
                isSmallScreen: isSmallScreen,
              ),
              _buildOperationCard(
                title: 'Inverse',
                icon: Icons.swap_horizontal_circle_rounded,
                color: const Color(0xFF8B5CF6),
                enabled: isSquare,
                onTap: _onCalculateInverse,
                description: 'A⁻¹',
                isSmallScreen: isSmallScreen,
              ),
              _buildOperationCard(
                title: 'Transpose',
                icon: Icons.swap_vert_circle_rounded,
                color: const Color(0xFFF59E0B),
                enabled: true,
                onTap: () => _onCalculateTranspose(),
                description: 'Aᵀ',
                isSmallScreen: isSmallScreen,
              ),
              _buildOperationCard(
                title: 'Rank',
                icon: Icons.stacked_line_chart_rounded,
                color: const Color(0xFFEF4444),
                enabled: true,
                onTap: _onCalculateRank,
                description: 'rank(A)',
                isSmallScreen: isSmallScreen,
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 24 : 32),
          Divider(
            color: const Color(0xFFF1F5F9),
            thickness: 1.5,
            height: 1,
          ),
          SizedBox(height: isSmallScreen ? 16 : 24),
          
          // RREF Preview
          Text(
            'RREF PREVIEW',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: _buildRREFPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    final bool isSquare = rows == cols;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADVANCED METHODS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Numerical methods for system solving',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          
          // Method Cards
          Column(
            children: [
              _buildMethodCard(
                title: 'LU Decomposition',
                icon: Icons.account_tree_rounded,
                color: const Color(0xFFEC4899),
                enabled: isSquare,
                onTap: _onShowLUSteps,
                description: 'A = LU decomposition with pivot steps',
              ),
              const SizedBox(height: 16),
              _buildMethodCard(
                title: 'Gaussian Elimination',
                icon: Icons.linear_scale_rounded,
                color: const Color(0xFF3B82F6),
                enabled: true,
                onTap: () => _showOBEViewer(0),
                description: 'Step-by-step elimination process',
              ),
              const SizedBox(height: 16),
              _buildMethodCard(
                title: 'Matrix Multiplication',
                icon: Icons.close_rounded,
                color: const Color(0xFFF59E0B),
                enabled: true,
                onTap: _onMatrixMultiply,
                description: 'Multiply current matrix with another',
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 24),
          
          // Matrix Properties
          const Text(
            'MATRIX PROPERTIES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildPropertyRow('Dimensions', '$rows × $cols', Icons.aspect_ratio_rounded),
                  const Divider(color: Color(0xFFF1F5F9), thickness: 1.5, height: 24),
                  _buildPropertyRow('Type', isSquare ? 'Square' : 'Rectangular', Icons.category_rounded),
                  const Divider(color: Color(0xFFF1F5F9), thickness: 1.5, height: 24),
                  _buildPropertyRow('Variables', '$cols variables', Icons.numbers_rounded),
                  const Divider(color: Color(0xFFF1F5F9), thickness: 1.5, height: 24),
                  _buildPropertyRow('Equations', '$rows equations', Icons.format_list_numbered_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
    required String description,
    required bool isSmallScreen,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: enabled ? color.withOpacity(0.05) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled ? color.withOpacity(0.1) : const Color(0xFFF1F5F9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isSmallScreen ? 44 : 56,
                height: isSmallScreen ? 44 : 56,
                decoration: BoxDecoration(
                  gradient: enabled
                      ? LinearGradient(
                          colors: [color, Color.lerp(color, Colors.black, 0.1)!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            const Color(0xFFCBD5E1),
                            const Color(0xFF94A3B8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  shape: BoxShape.circle,
                  boxShadow: enabled ? [
                    BoxShadow(
                      color: enabled ? color.withOpacity(0.3) : Colors.transparent,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ] : [],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: enabled ? Colors.white : const Color(0xFFF8FAFC),
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: enabled ? color : const Color(0xFF94A3B8),
                  fontSize: isSmallScreen ? 12 : 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmallScreen ? 9 : 11,
                  color: enabled ? color.withOpacity(0.7) : const Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
    required String description,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? color.withOpacity(0.1) : const Color(0xFFF1F5F9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: enabled
                      ? LinearGradient(
                          colors: [color, Color.lerp(color, Colors.black, 0.1)!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: [
                            const Color(0xFFCBD5E1),
                            const Color(0xFF94A3B8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: enabled ? color.withOpacity(0.2) : Colors.transparent,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon,
                    color: enabled ? Colors.white : const Color(0xFFF8FAFC),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: enabled ? color : const Color(0xFF94A3B8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? color : const Color(0xFFCBD5E1),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF64748B),
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRREFPreview() {
    final aug = _readAugmentedMatrix();
    if (aug.isEmpty) return const SizedBox();
    
    final cellWidth = 60.0;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          for (int i = 0; i < aug.length; i++)
            Row(
              children: [
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A11CB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'R${i+1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                ...List.generate(aug[i].length, (j) {
                  final isLast = j == aug[i].length - 1;
                  return Container(
                    width: cellWidth,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      gradient: isLast
                          ? LinearGradient(
                              colors: [
                                Colors.red.shade50,
                                Colors.red.shade100,
                            ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [Colors.white, const Color(0xFFF8FAFC)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      border: Border.all(
                        color: isLast ? Colors.red.shade200 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      aug[i][j].toStringAsFixed(precision),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isLast ? Colors.red.shade700 : const Color(0xFF334155),
                        fontFamily: 'Monospace',
                      ),
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER METHODS ---

  void _showResultDialog({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                const Color(0xFFF8FAFC),
            ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor,
                        Color.lerp(iconColor, Colors.black, 0.1)!,
                    ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                content,
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'CLOSE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showOBEViewer(int startIndex) async {
    if (obeSnapshots.isEmpty) return;
    
    await showDialog(
      context: context,
      builder: (ctx) => _OBEViewerDialog(
        snapshots: obeSnapshots,
        descriptions: obeDescriptions,
        precision: precision,
        startIndex: startIndex,
      ),
    );
  }

  IconData _getStatusIcon() {
    if (isCalculating) return Icons.hourglass_top_rounded;
    if (solution.isEmpty) return Icons.info_outline_rounded;
    if (lastOperationLabel.contains('Unique')) return Icons.check_circle_rounded;
    if (lastOperationLabel.contains('Parametric')) return Icons.warning_rounded;
    return Icons.info_outline_rounded;
  }

  Color _getStatusColor() {
    if (isCalculating) return const Color(0xFFF59E0B);
    if (solution.isEmpty) return const Color(0xFF64748B);
    if (lastOperationLabel.contains('Unique')) return const Color(0xFF10B981);
    if (lastOperationLabel.contains('Parametric')) return const Color(0xFFF59E0B);
    if (lastOperationLabel.contains('Inconsistent')) return const Color(0xFFEF4444);
    return const Color(0xFF64748B);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copySolutionCSV() {
    if (solution.isEmpty) return;
    final csv = solution.map((v) => v.toStringAsFixed(precision)).join(', ');
    Clipboard.setData(ClipboardData(text: csv));
    _showSuccess('Solution copied to clipboard');
  }

  void _copyMatrixToClipboard(List<List<double>> matrix) {
    final buffer = StringBuffer();
    for (var row in matrix) {
      buffer.writeln(row.map((v) => v.toStringAsFixed(precision)).join('\t'));
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showSuccess('Matrix copied to clipboard');
  }

  void _onCalculateTranspose() {
    final A = _readMatrixAOnly();
    final transposed = MatrixOps.transpose(A);
    
    _showResultDialog(
      title: 'Matrix Transpose',
      icon: Icons.swap_vert_circle_rounded,
      iconColor: const Color(0xFFF59E0B),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Aᵀ =',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: transposed.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: row.map((val) {
                        return Container(
                          width: 70,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                const Color(0xFFF8FAFC),
                            ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            val.toStringAsFixed(precision),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onCalculateRank() {
    final A = _readMatrixAOnly();
    final rank = MatrixOps.rank(A);

    _showResultDialog(
      title: 'Matrix Rank',
      icon: Icons.stacked_line_chart_rounded,
      iconColor: const Color(0xFFEF4444),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'rank(A) =',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFEF2F2),
                  const Color(0xFFFEE2E2),
              ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFECACA),
                width: 1.5,
              ),
            ),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            rank == min(rows, cols) 
                ? 'Matrix has full rank'
                : 'Matrix is rank-deficient',
            style: TextStyle(
              color: rank == min(rows, cols) 
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rank == min(rows, cols)
                ? 'All rows/columns are linearly independent'
                : 'Some rows/columns are linearly dependent',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onShowLUSteps() async {
    if (rows != cols) {
      _showError('LU decomposition requires square matrix');
      return;
    }

    setState(() => isCalculating = true);

    try {
      final aug = _readAugmentedMatrix();
      if (aug.length < cols) {
        _showError('Invalid matrix dimensions');
        return;
      }

      List<List<double>> A = List.generate(cols, (i) => List.filled(cols, 0.0));
      List<double> b = List.filled(cols, 0.0);
      for (int i = 0; i < cols; i++) {
        for (int j = 0; j < cols; j++) {
          A[i][j] = aug[i][j];
        }
        b[i] = aug[i][cols];
      }

      final res = MatrixOps.luSolveToStringSteps(A, b);
      final List<String> decompSteps = List<String>.from(res['decompositionSteps'] ?? []);
      final List<String> forwardSteps = List<String>.from(res['forwardSteps'] ?? []);
      final List<String> backwardSteps = List<String>.from(res['backwardSteps'] ?? []);
      final List<double>? sol = (res['solution'] != null) 
          ? List<double>.from(res['solution']) 
          : null;

      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFEC4899),
                        const Color(0xFF8B5CF6),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                        ),
                        child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'LU DECOMPOSITION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
                DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      Container(
                        height: 48,
                        color: Colors.white,
                        child: TabBar(
                          labelColor: const Color(0xFFEC4899),
                          unselectedLabelColor: const Color(0xFF64748B),
                          indicatorColor: const Color(0xFFEC4899),
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          tabs: const [
                            Tab(text: 'Decomposition'),
                            Tab(text: 'Forward Sub'),
                            Tab(text: 'Backward Sub'),
                            Tab(text: 'Solution'),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 320,
                        child: TabBarView(
                          children: [
                            _buildStepsListView(decompSteps),
                            _buildStepsListView(forwardSteps),
                            _buildStepsListView(backwardSteps),
                            _buildSolutionView(sol),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      setState(() => isCalculating = false);
    }
  }

  Widget _buildStepsListView(List<String> steps) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SelectableText(
                    steps[index],
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSolutionView(List<double>? sol) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    
    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: sol == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60, // PERKECIL DARI 80
                  height: 60, // PERKECIL DARI 80
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFECACA), width: 2),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 30, // PERKECIL DARI 40
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 16), // PERKECIL DARI 20
                Text(
                  'No solution found',
                  style: TextStyle(
                    color: const Color(0xFFDC2626),
                    fontSize: isSmallScreen ? 16 : 18, // PERKECIL
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Matrix may be singular or inconsistent',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontSize: isSmallScreen ? 12 : 14, // PERKECIL
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solution:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18, // PERKECIL
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: isSmallScreen ? 8 : 12, // PERKECIL SPACING
                    runSpacing: isSmallScreen ? 8 : 12,
                    children: List.generate(sol.length, (i) {
                      return Container(
                        width: isSmallScreen ? 90 : 100, // PERKECIL DARI 120
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16), // PERKECIL
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFDF4FF),
                              const Color(0xFFFAE8FF),
                          ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12), // PERKECIL RADIUS
                          border: Border.all(color: const Color(0xFFF5D0FE), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10, // PERKECIL BLUR
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 8 : 10,
                                vertical: isSmallScreen ? 4 : 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFEC4899),
                                    const Color(0xFF8B5CF6),
                                ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16), // PERKECIL
                              ),
                              child: Text(
                                'x${i + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 12 : 14, // PERKECIL
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 6 : 8),
                            Text(
                              sol[i].toStringAsFixed(precision),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18, // PERKECIL
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
    );
  }

  void _onMatrixMultiply() {
    _showInfo('Matrix multiplication feature coming soon!');
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                const Color(0xFFF8FAFC),
            ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
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
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Matrix Solver Help',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How to use the app',
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _HelpItem(
                      number: '1',
                      title: 'Enter your matrix',
                      description: 'Input matrix A and vector b for Ax = b system',
                    ),
                    SizedBox(height: 16),
                    _HelpItem(
                      number: '2',
                      title: 'Adjust dimensions',
                      description: 'Use + and - buttons to change matrix size',
                    ),
                    SizedBox(height: 16),
                    _HelpItem(
                      number: '3',
                      title: 'Solve system',
                      description: 'Click "Solve System" to get solution',
                    ),
                    SizedBox(height: 16),
                    _HelpItem(
                      number: '4',
                      title: 'View operations',
                      description: 'Check step-by-step solutions in tabs',
                    ),
                    SizedBox(height: 16),
                    _HelpItem(
                      number: '5',
                      title: 'Advanced features',
                      description: 'Use operations tab for matrix analysis',
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A11CB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'GOT IT',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayScaleLabel() {
    if (_displayScale < 0.9) return 'Small';
    if (_displayScale < 1.1) return 'Medium';
    return 'Large';
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_displayScale),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(),
        endDrawer: _buildSettingsDrawer(),
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : _contentPadding,
            ),
            child: Column(
              children: [
                SizedBox(height: isSmallScreen ? 8 : 12),
                _buildMatrixInputCard(),
                _buildSolutionCard(),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.code_rounded,
                        size: isSmallScreen ? 12 : 14,
                        color: const Color(0xFF64748B),
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Text(
                        'Matrix Solver Pro • v1.0',
                        style: TextStyle(
                          color: const Color(0xFF64748B).withOpacity(0.8),
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _HelpItem({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// OBE Viewer Dialog as separate widget
class _OBEViewerDialog extends StatefulWidget {
  final List<List<List<double>>> snapshots;
  final List<String> descriptions;
  final int precision;
  final int startIndex;

  const _OBEViewerDialog({
    required this.snapshots,
    required this.descriptions,
    required this.precision,
    required this.startIndex,
  });

  @override
  __OBEViewerDialogState createState() => __OBEViewerDialogState();
}

class __OBEViewerDialogState extends State<_OBEViewerDialog> {
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.startIndex;
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    final snapshot = widget.snapshots[currentIndex];
    final description = widget.descriptions[currentIndex];
    final totalSteps = widget.snapshots.length;

    return Dialog(
      insetPadding: EdgeInsets.all(isSmallScreen ? 8 : 16), // TAMBAH INI
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? MediaQuery.of(context).size.width * 0.95 : 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - PERKECIL
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6),
                    const Color(0xFF1D4ED8),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 40 : 48,
                    height: isSmallScreen ? 40 : 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Icon(
                      Icons.format_list_numbered_rounded,
                      color: Colors.white,
                      size: isSmallScreen ? 20 : 24,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STEP-BY-STEP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 14 : 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 2 : 4),
                        Text(
                          'Step ${currentIndex + 1} of $totalSteps',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: isSmallScreen ? 11 : 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: isSmallScreen ? 20 : 24,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content - PERKECIL
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                children: [
                  // Description - PERKECIL
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE0F2FE),
                          const Color(0xFFBAE6FD),
                      ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF7DD3FC), width: 1.5),
                    ),
                    child: Text(
                      description,
                      style: TextStyle(
                        color: const Color(0xFF0369A1),
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallScreen ? 12 : 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 24),
                  
                  // Matrix Display - PERKECIL
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: snapshot.asMap().entries.map((entry) {
                          final i = entry.key;
                          final row = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(bottom: i < snapshot.length - 1 ? 8 : 0),
                            child: Row(
                              children: row.asMap().entries.map((cell) {
                                final isLast = cell.key == row.length - 1;
                                return Container(
                                  width: isSmallScreen ? 55 : 65, // PERKECIL
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallScreen ? 8 : 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isLast
                                        ? LinearGradient(
                                            colors: [
                                              Colors.red.shade50,
                                              Colors.red.shade100,
                                          ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : LinearGradient(
                                            colors: [Colors.white, const Color(0xFFF8FAFC)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    border: Border.all(
                                      color: isLast 
                                          ? Colors.red.shade200 
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    cell.value.toStringAsFixed(widget.precision),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 10 : 12, // PERKECIL
                                      fontWeight: FontWeight.w600,
                                      color: isLast 
                                          ? Colors.red.shade700 
                                          : const Color(0xFF334155),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 24),
                  
                  // Navigation - PERKECIL
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: isSmallScreen ? 42 : 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: currentIndex > 0
                                ? () => setState(() => currentIndex--)
                                : null,
                            icon: Icon(
                              Icons.navigate_before_rounded,
                              size: isSmallScreen ? 18 : 20,
                              color: const Color(0xFF475569),
                            ),
                            label: Text(
                              'Previous',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12 : 16),
                      Expanded(
                        child: Container(
                          height: isSmallScreen ? 42 : 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF10B981),
                                const Color(0xFF059669),
                            ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: currentIndex < totalSteps - 1
                                ? () => setState(() => currentIndex++)
                                : null,
                            icon: Icon(
                              Icons.navigate_next_rounded,
                              size: isSmallScreen ? 18 : 20,
                              color: Colors.white,
                            ),
                            label: Text(
                              'Next',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
