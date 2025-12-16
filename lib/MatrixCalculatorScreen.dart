// lib/MatrixCalculatorScreen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'MatrixUtils.dart';

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
  double _displayScale = 1.0; // Tambah variabel untuk display scale

  List<double> solution = [];
  String lastOperationLabel = '';
  String operationStatus = 'Ready';

  List<List<List<double>>> obeSnapshots = [];
  List<String> obeDescriptions = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
        icon: Icons.functions,
        iconColor: const Color(0xFF10B981),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'det(A) =',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              det.toStringAsFixed(6),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(
                  icon: Icons.info_outline,
                  label: det.abs() < 1e-12 ? 'Singular' : 'Non-singular',
                  color: det.abs() < 1e-12 ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.compare_arrows,
                  // ignore: unnecessary_brace_in_string_interps
                  label: '${rows} × $rows',
                  color: Colors.blue,
                ),
              ],
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
        icon: Icons.swap_horiz,
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
                  fontSize: 16,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: inv.asMap().entries.map((entry) {
                      final i = entry.key;
                      final row = entry.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: i < inv.length - 1 ? 8 : 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: row.asMap().entries.map((cell) {
                            return Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    // ignore: deprecated_member_use
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 3,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                cell.value.toStringAsFixed(precision),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Monospace',
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _copyMatrixToClipboard(inv),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Matrix', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    foregroundColor: const Color(0xFF374151),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A1A),
      centerTitle: true,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_on, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          const Text(
            'MATRIX SOLVER',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary, size: 22),
          tooltip: 'Settings',
          padding: const EdgeInsets.all(8),
        ),
      ],
      toolbarHeight: 56,
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.settings, color: Colors.white, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'SETTINGS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Matrix Solver Pro',
                    style: TextStyle(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'DISPLAY SETTINGS',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Precision Slider
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.precision_manufacturing, 
                                  color: Theme.of(context).colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Decimal Precision',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('$precision decimal places',
                              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                          Slider(
                            value: precision.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Colors.grey.shade300,
                            onChanged: (value) {
                              setState(() => precision = value.toInt());
                            },
                          ),
                          const Text(
                            'Controls number of decimal places shown in results',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Display Scale Slider
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.text_fields, 
                                  color: Theme.of(context).colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Display Scale',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getDisplayScaleLabel(),
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                          ),
                          Slider(
                            value: _displayScale,
                            min: 0.8,
                            max: 1.2,
                            divisions: 4,
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Colors.grey.shade300,
                            onChanged: (value) {
                              setState(() => _displayScale = value);
                            },
                          ),
                          const Text(
                            'Adjusts the overall display size of the interface',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'APP TOOLS',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // App Tools - Hanya menyisakan Help & Tutorial
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.help_outline,
                              color: Theme.of(context).colorScheme.primary, size: 22),
                          title: const Text('Help & Tutorial', style: TextStyle(fontSize: 14)),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => _showHelpDialog(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // App Info
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Matrix Solver Pro v1.0',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface
                                // ignore: deprecated_member_use
                                .withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Linear Algebra Toolkit',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurface
                                // ignore: deprecated_member_use
                                .withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixInputCard() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.grid_on, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INPUT MATRIX',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enter matrix A and vector b for Ax = b',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (solution.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${solution.length} variables',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Dimension Controls
                  _buildDimensionControls(),
                  const SizedBox(height: 16),
                  
                  // Matrix Grid
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildMatrixGrid(),
                  ),
                  const SizedBox(height: 16),
                  
                  // Status Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(),
                          color: _getStatusColor(),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            operationStatus,
                            style: TextStyle(
                              color: _getStatusColor(),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionControls() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.aspect_ratio, size: 18, color: Color(0xFF6B7280)),
                SizedBox(width: 6),
                Text(
                  'MATRIX DIMENSIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDimensionControl(
                  label: 'ROWS',
                  value: rows,
                  onDecrease: rows > minDim ? () => _resize(rows - 1, cols) : null,
                  onIncrease: rows < maxDim ? () => _resize(rows + 1, cols) : null,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: const Color(0xFFE5E7EB),
                ),
                _buildDimensionControl(
                  label: 'COLUMNS',
                  value: cols,
                  onDecrease: cols > minDim ? () => _resize(rows, cols - 1) : null,
                  onIncrease: cols < maxDim ? () => _resize(rows, cols + 1) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionControl({
    required String label,
    required int value,
    VoidCallback? onDecrease,
    VoidCallback? onIncrease,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlButton(
              icon: Icons.remove,
              onPressed: onDecrease,
              isEnabled: onDecrease != null,
            ),
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            _buildControlButton(
              icon: Icons.add,
              onPressed: onIncrease,
              isEnabled: onIncrease != null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isEnabled,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(8),
      color: isEnabled
          ? Theme.of(context).colorScheme.primary
          : const Color(0xFFE5E7EB),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isEnabled ? Colors.white : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixGrid() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40),
                // ignore: sized_box_for_whitespace
                ...List.generate(cols, (j) => Container(
                  width: 50,
                  child: Center(
                    child: Text(
                      'x${j+1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                        fontSize: 12,
                      ),
                    ),
                  ),
                )),
                // ignore: sized_box_for_whitespace
                Container(
                  width: 50,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_right_alt, 
                            size: 14, color: Colors.red.shade600),
                        const SizedBox(width: 2),
                        Text(
                          'b',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Colors.red.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rows
          ...List.generate(rows, (i) => Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: i % 2 == 0 ? Colors.white : const Color(0xFFFCFCFC),
              border: i < rows - 1
                ? const Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))
                : null,
            ),
            child: Row(
              children: [
                // ignore: sized_box_for_whitespace
                Container(
                  width: 40,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'R${i+1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                ...List.generate(cols, (j) => Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextField(
                    controller: controllers[i][j],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
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
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: TextField(
                    controller: controllers[i][cols],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade600,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.red.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.red.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: Colors.red.shade600,
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
        const SizedBox(height: 12),
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
    return ElevatedButton(
      onPressed: isCalculating ? null : _onCalculateSPL,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(double.infinity, 52),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: isCalculating
            ? [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'SOLVING...',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ]
            : [
                Icon(Icons.calculate, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'SOLVE SYSTEM',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return OutlinedButton(
      onPressed: _clearAll,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
        minimumSize: const Size(0, 52),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.clear, size: 18),
          SizedBox(width: 6),
          Text(
            'CLEAR',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionCard() {
    if (solution.isEmpty && lastOperationLabel.isEmpty) return const SizedBox();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF11998e),
                    const Color(0xFF38ef7d),
                ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.analytics, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SOLUTIONS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lastOperationLabel,
                          style: TextStyle(
                            // ignore: deprecated_member_use
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
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
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        lastOperationLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
                  SizedBox(
                    height: 40,
                    child: TabBar(
                      labelColor: const Color(0xFF11998e),
                      unselectedLabelColor: const Color(0xFF6B7280),
                      indicatorColor: const Color(0xFF11998e),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                      tabs: const [
                        Tab(text: 'SOLUTION'),
                        Tab(text: 'OPERATIONS'),
                        Tab(text: 'ADVANCED'),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 300,
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
    );
  }

  Widget _buildSolutionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SYSTEM SOLUTION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          
          if (solution.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome_mosaic,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Solution Calculated',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Click "Solve System" to find solution for Ax = b',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE3F2FD),
                        const Color(0xFFF3E5F5),
                    ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Solution Vector x:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: List.generate(solution.length, (i) {
                          return Container(
                            width: 80,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  // ignore: deprecated_member_use
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'x${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  solution[i].toStringAsFixed(precision),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F2937),
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
                const SizedBox(height: 16),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _copySolutionCSV,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Values', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showOBEViewer(0),
                        icon: const Icon(Icons.visibility, size: 16),
                        label: const Text('View Steps', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    final bool isSquare = rows == cols;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MATRIX OPERATIONS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isSquare ? 'Square Matrix ($rows × $rows)' : 'Non-square Matrix',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Matrix Operations Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildOperationCard(
                title: 'Determinant',
                icon: Icons.functions,
                color: const Color(0xFF10B981),
                enabled: isSquare,
                onTap: _onCalculateDet,
                description: 'Calculate det(A)',
              ),
              _buildOperationCard(
                title: 'Inverse',
                icon: Icons.swap_horiz,
                color: const Color(0xFF8B5CF6),
                enabled: isSquare,
                onTap: _onCalculateInverse,
                description: 'Compute A⁻¹',
              ),
              _buildOperationCard(
                title: 'Transpose',
                icon: Icons.swap_vert,
                color: const Color(0xFFF59E0B),
                enabled: true,
                onTap: _onCalculateTranspose,
                description: 'Find Aᵀ',
              ),
              _buildOperationCard(
                title: 'Rank',
                icon: Icons.stacked_line_chart,
                color: const Color(0xFFEF4444),
                enabled: true,
                onTap: _onCalculateRank,
                description: 'Matrix rank',
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          
          // RREF Preview
          const Text(
            'RREF PREVIEW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(10),
            child: _buildRREFPreview(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    final bool isSquare = rows == cols;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADVANCED METHODS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Numerical methods for system solving',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          
          // Method Cards
          Column(
            children: [
              _buildMethodCard(
                title: 'LU Decomposition',
                icon: Icons.account_tree,
                color: const Color(0xFFEC4899),
                enabled: isSquare,
                onTap: _onShowLUSteps,
                description: 'A = LU decomposition with pivot steps',
              ),
              const SizedBox(height: 12),
              _buildMethodCard(
                title: 'Gaussian Elimination',
                icon: Icons.linear_scale,
                color: const Color(0xFF3B82F6),
                enabled: true,
                onTap: () => _showOBEViewer(0),
                description: 'Step-by-step elimination process',
              ),
              const SizedBox(height: 12),
              _buildMethodCard(
                title: 'Matrix Multiplication',
                icon: Icons.close,
                color: const Color(0xFFF59E0B),
                enabled: true,
                onTap: _onMatrixMultiply,
                description: 'Multiply current matrix with another',
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          
          // Matrix Properties
          const Text(
            'MATRIX PROPERTIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildPropertyRow('Dimensions', '$rows × $cols'),
                  const Divider(),
                  _buildPropertyRow('Type', isSquare ? 'Square' : 'Rectangular'),
                  const Divider(),
                  _buildPropertyRow('Variables', '$cols variables'),
                  const Divider(),
                  _buildPropertyRow('Equations', '$rows equations'),
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
  }) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              // ignore: deprecated_member_use
              color: enabled ? color.withOpacity(0.3) : Colors.grey.shade200,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: enabled ? color.withOpacity(0.1) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: enabled ? color : Colors.grey.shade400,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: enabled ? color : Colors.grey.shade400,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
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
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              // ignore: deprecated_member_use
              color: enabled ? color.withOpacity(0.2) : Colors.grey.shade200,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: enabled ? color.withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: enabled ? color : Colors.grey.shade400,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: enabled ? color : Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: enabled ? color : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRREFPreview() {
    final aug = _readAugmentedMatrix();
    if (aug.isEmpty) return const SizedBox();
    
    final cellWidth = 55.0;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          for (int i = 0; i < aug.length; i++)
            Row(
              children: [
                Container(
                  width: 35,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'R${i+1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      fontSize: 10,
                    ),
                  ),
                ),
                ...List.generate(aug[i].length, (j) {
                  final isLast = j == aug[i].length - 1;
                  return Container(
                    width: cellWidth,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                    decoration: BoxDecoration(
                      color: isLast ? Colors.red.shade50 : Colors.white,
                      border: Border.all(
                        color: isLast ? Colors.red.shade100 : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      aug[i][j].toStringAsFixed(precision),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isLast ? Colors.red.shade700 : const Color(0xFF374151),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        // ignore: deprecated_member_use
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              content,
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
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
    if (isCalculating) return Icons.hourglass_top;
    if (solution.isEmpty) return Icons.info_outline;
    if (lastOperationLabel.contains('Unique')) return Icons.check_circle;
    if (lastOperationLabel.contains('Parametric')) return Icons.warning;
    return Icons.info_outline;
  }

  Color _getStatusColor() {
    if (isCalculating) return const Color(0xFFF59E0B);
    if (solution.isEmpty) return const Color(0xFF6B7280);
    if (lastOperationLabel.contains('Unique')) return const Color(0xFF10B981);
    if (lastOperationLabel.contains('Parametric')) return const Color(0xFFF59E0B);
    if (lastOperationLabel.contains('Inconsistent')) return const Color(0xFFEF4444);
    return const Color(0xFF6B7280);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
      icon: Icons.swap_vert,
      iconColor: const Color(0xFFF59E0B),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Aᵀ =',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                children: transposed.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: row.map((val) {
                        return Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                // ignore: deprecated_member_use
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            val.toStringAsFixed(precision),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
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
      icon: Icons.stacked_line_chart,
      iconColor: const Color(0xFFEF4444),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'rank(A) =',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$rank',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            rank == min(rows, cols) 
                ? 'Matrix has full rank'
                : 'Matrix is rank-deficient',
            style: TextStyle(
              color: rank == min(rows, cols) 
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
              fontWeight: FontWeight.w600,
              fontSize: 13,
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
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
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
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'LU DECOMPOSITION',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 40,
                        child: TabBar(
                          labelColor: const Color(0xFFEC4899),
                          unselectedLabelColor: const Color(0xFF6B7280),
                          indicatorColor: const Color(0xFFEC4899),
                          indicatorWeight: 3,
                          labelStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 11,
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
                        height: 300,
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
      padding: const EdgeInsets.all(12),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    steps[index],
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF374151),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: sol == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No solution found',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solution:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(sol.length, (i) {
                    return Container(
                      width: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            // ignore: deprecated_member_use
                            const Color(0xFFEC4899).withOpacity(0.1),
                            // ignore: deprecated_member_use
                            const Color(0xFF8B5CF6).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'x${i + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEC4899),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sol[i].toStringAsFixed(precision),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
    );
  }

  void _onMatrixMultiply() {
    _showInfo('Matrix multiplication feature coming soon!');
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.help_outline,
                size: 50,
                color: Color(0xFF6A11CB),
              ),
              const SizedBox(height: 16),
              const Text(
                'Matrix Solver Help',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '1. Enter your matrix A and vector b\n'
                '2. Adjust dimensions as needed\n'
                '3. Click "Solve System" for solution\n'
                '4. Use operations tab for matrix analysis\n'
                '5. View step-by-step solutions',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('GOT IT', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
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
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        // ignore: deprecated_member_use
        textScaleFactor: _displayScale,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(),
        endDrawer: _buildSettingsDrawer(),
        backgroundColor: const Color(0xFFF8F9FA),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildMatrixInputCard(),
                _buildSolutionCard(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF3F4F6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.code,
                        size: 12,
                        color: const Color(0xFF757575),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Matrix Solver Pro • v1.0 • Precision: $precision • Scale: ${_getDisplayScaleLabel()}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10,
                        ),
                      ),
                    ],
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
    final snapshot = widget.snapshots[currentIndex];
    final description = widget.descriptions[currentIndex];
    final totalSteps = widget.snapshots.length;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF3B82F6),
                  const Color(0xFF1D4ED8),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STEP-BY-STEP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Step ${currentIndex + 1} of $totalSteps',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Description
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF0369A1),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Matrix Display
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(12),
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
                                width: 55,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isLast ? Colors.red.shade50 : Colors.white,
                                  border: Border.all(
                                    color: isLast 
                                        ? Colors.red.shade200 
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Text(
                                  cell.value.toStringAsFixed(widget.precision),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isLast 
                                        ? Colors.red.shade700 
                                        : const Color(0xFF1F2937),
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
                const SizedBox(height: 16),
                
                // Navigation
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: currentIndex > 0
                            ? () => setState(() => currentIndex--)
                            : null,
                        icon: const Icon(Icons.navigate_before, size: 18),
                        label: const Text('Previous', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: currentIndex < totalSteps - 1
                            ? () => setState(() => currentIndex++)
                            : null,
                        icon: const Icon(Icons.navigate_next, size: 18),
                        label: const Text('Next', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF10B981),
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
    );
  }
}