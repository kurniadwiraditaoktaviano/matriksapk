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

class _MatrixCalculatorScreenState extends State<MatrixCalculatorScreen> {
  // --- STATE VARIABLES ---
  int rows = 4, cols = 4;
  static const int maxDim = 6;
  static const int minDim = 1;

  late List<List<TextEditingController>> controllers;
  int precision = 2; // Default 2 angka belakang koma

  List<double> solution = [];
  String lastOperationLabel = '';

  List<List<List<double>>> obeSnapshots = [];
  List<String> obeDescriptions = [];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void dispose() {
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
      (i) => List.generate(cols + 1, (j) => TextEditingController(text: '0')),
    );
  }

  void _resize(int newRows, int newCols) {
    final oldR = controllers.length;
    final oldC = controllers.isNotEmpty ? controllers[0].length : 0;
    List<List<TextEditingController>> next = List.generate(
      newRows,
      (i) => List.generate(
          newCols + 1, (j) => TextEditingController(text: '0')),
    );

    for (int i = 0; i < min(newRows, oldR); i++) {
      for (int j = 0; j < min(newCols + 1, oldC); j++) {
        next[i][j].text = controllers[i][j].text;
      }
    }

    // dispose old
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
  void _onCalculateDet() {
    if (rows != cols) {
      _showSnack('Determinan hanya untuk matriks persegi (Baris = Kolom)');
      return;
    }
    final A = _readMatrixAOnly();
    final det = MatrixOps.determinant(A);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Determinan Matriks A'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.functions, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              det.toStringAsFixed(4), // Default 4 digit untuk det agar akurat
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Nilai Determinan', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))
        ],
      ),
    );
  }

  void _onCalculateInverse() {
    if (rows != cols) {
      _showSnack('Invers hanya untuk matriks persegi (Baris = Kolom)');
      return;
    }
    final A = _readMatrixAOnly();
    final inv = MatrixOps.inverse(A);

    if (inv == null) {
      _showSnack('Matriks singular (Determinan = 0), tidak memiliki invers.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Invers Matriks A'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('A⁻¹ =', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: inv.map((row) {
                    return Row(
                      children: row.map((val) {
                        return Container(
                          width: 60,
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4)
                          ),
                          child: Text(
                            val.toStringAsFixed(precision),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))
        ],
      ),
    );
  }

  void _recordOBE(List<List<double>> mat, String desc) {
    final snap = mat.map((r) => List<double>.from(r)).toList();
    obeSnapshots.add(snap);
    obeDescriptions.add(desc);
  }

  void _computeRREFAndSolution() {
    final aug = _readAugmentedMatrix();
    final n = rows;
    final m = cols + 1;
    List<List<double>> mat = List.generate(n, (i) => List.from(aug[i]));

    obeSnapshots.clear();
    obeDescriptions.clear();
    _recordOBE(mat, 'Matriks awal ([A | B])');

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
        _recordOBE(mat, 'Swap baris $sel dan baris $r');
      }

      final pivot = mat[r][c];
      if (pivot.abs() < 1e-15) continue;
      for (int j = c; j < m; j++) {
        mat[r][j] /= pivot;
      }
      _recordOBE(mat, 'Normalisasi baris $r (pivot di kolom $c dibuat 1)');

      for (int i = 0; i < n; i++) {
        if (i == r) continue;
        final factor = mat[i][c];
        if (factor.abs() < 1e-12) continue;
        for (int j = c; j < m; j++) {
          mat[i][j] -= factor * mat[r][j];
        }
        _recordOBE(
            mat, 'Eliminasi: gunakan baris $r untuk mengeliminasi entri pada baris $i');
      }
      r++;
    }

    // Check inconsistent
    for (int i = 0; i < n; i++) {
      bool allZero = true;
      for (int j = 0; j < cols; j++) {
        if (mat[i][j].abs() > 1e-9) allZero = false;
      }
      if (allZero && mat[i][cols].abs() > 1e-9) {
        setState(() {
          solution = [];
          lastOperationLabel = 'Sistem tidak konsisten (tidak ada solusi)';
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
      lastOperationLabel =
          unique ? 'Solusi tunggal' : 'Solusi parametrik / banyak solusi';
    });
  }

  void _onCalculateSPL() {
    _computeRREFAndSolution();
    if (obeSnapshots.isNotEmpty) _showOBEViewer(0);
  }

  void _clearAll() {
    for (var row in controllers)
      // ignore: curly_braces_in_flow_control_structures
      for (var c in row) {
        c.text = '0';
      }
    setState(() {
      solution = [];
      lastOperationLabel = '';
      obeSnapshots.clear();
      obeDescriptions.clear();
    });
  }

  Future<void> _onShowLUSteps() async {
    if (rows != cols) {
      _showSnack('Untuk LU, matriks A harus persegi (rows == cols).');
      return;
    }
    final aug = _readAugmentedMatrix();
    if (aug.length < cols) {
      _showSnack('Matriks tidak sesuai ukuran.');
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
    final List<String> decompSteps =
        List<String>.from(res['decompositionSteps'] ?? []);
    final List<String> forwardSteps =
        List<String>.from(res['forwardSteps'] ?? []);
    final List<String> backwardSteps =
        List<String>.from(res['backwardSteps'] ?? []);
    final List<double>? sol =
        (res['solution'] != null) ? List<double>.from(res['solution']) : null;

    await showDialog(
      context: context,
      builder: (ctx) {
        return DefaultTabController(
          length: 4,
          child: AlertDialog(
            title: const Text('Langkah LU & Penyelesaian'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TabBar(
                    labelColor: Colors.deepPurple,
                    indicatorColor: Colors.deepPurple,
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Dekomposisi'),
                      Tab(text: 'Forward'),
                      Tab(text: 'Backward'),
                      Tab(text: 'Solusi'),
                    ],
                  ),
                  SizedBox(
                    height: 300,
                    child: TabBarView(children: [
                      _stepsListView(decompSteps),
                      _stepsListView(forwardSteps),
                      _stepsListView(backwardSteps),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: sol == null
                            ? const Center(
                                child: Text(
                                    'Solusi tidak ditemukan atau matriks singular.'))
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Solusi:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: List.generate(sol.length, (i) {
                                        return Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              color: Colors.grey.shade100),
                                          child: Text(
                                              'x${i + 1} = ${sol[i].toStringAsFixed(precision)}'),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ]),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'))
            ],
          ),
        );
      },
    );
  }

  Widget _stepsListView(List<String> steps) {
    if (steps.isEmpty)
      // ignore: curly_braces_in_flow_control_structures
      return const Center(child: Text('Tidak ada langkah tersedia.'));
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SelectableText(steps[index]),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemCount: steps.length,
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // --- UI COMPONENTS ---

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      centerTitle: true,
      title: const Text('Matrix Solver'),
      // --- PERBAIKAN: MENAMBAHKAN KEMBALI TOMBOL PENGATURAN ---
      actions: [
        IconButton(
          onPressed: () {
            // Membuka Drawer Pengaturan (EndDrawer)
            _scaffoldKey.currentState?.openEndDrawer();
          },
          icon: const Icon(Icons.settings),
        ),
      ],
    );
  }

  // --- FITUR BARU: PANEL PENGATURAN ---
  Widget _buildSettingsDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.deepPurple),
            child: Container(
              width: double.infinity,
              alignment: Alignment.bottomLeft,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Icon(Icons.settings, color: Colors.white, size: 40),
                   SizedBox(height: 8),
                   Text('Pengaturan',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              )
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tampilan Hasil', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),

                // Slider Presisi
                Text('Jumlah Desimal (Presisi): $precision'),
                Row(
                  children: [
                    const Text('0', style: TextStyle(fontSize: 10)),
                    Expanded(
                      child: Slider(
                        value: precision.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: precision.toString(),
                        activeColor: Colors.deepPurple,
                        onChanged: (double val) {
                          setState(() {
                            precision = val.toInt();
                          });
                        },
                      ),
                    ),
                    const Text('10', style: TextStyle(fontSize: 10)),
                  ],
                ),
                const Text(
                  'Mengatur berapa angka di belakang koma yang ditampilkan pada hasil.',
                  style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                ),

                const Divider(height: 32),

                const Text('Lainnya', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Reset Matriks'),
                  onTap: () {
                    Navigator.pop(context); // Tutup drawer
                    _clearAll();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Tentang Aplikasi'),
                  onTap: () {
                    showDialog(context: context, builder: (ctx) => const AboutDialog(
                      applicationName: 'Matrix Solver',
                      applicationVersion: '1.0.0',
                      applicationLegalese: 'Dibuat dengan Flutter.',
                    ));
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMatrixInputCard() {
    return Card(
      elevation: 4,
      // ignore: deprecated_member_use
      shadowColor: Colors.deepPurple.withOpacity(0.2),
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grid_on, color: Colors.deepPurple),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Input Matriks ([A | B])',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Dimensi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('Baris', style: TextStyle(color: Colors.grey)),
                    Row(
                      children: [
                        _circleBtn(
                          icon: Icons.remove,
                          onTap: rows > minDim
                              ? () => _resize(rows - 1, cols)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$rows',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        _circleBtn(
                          icon: Icons.add,
                          onTap: rows < maxDim
                              ? () => _resize(rows + 1, cols)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Column(
                  children: [
                    const Text('Kolom', style: TextStyle(color: Colors.grey)),
                    Row(
                      children: [
                        _circleBtn(
                          icon: Icons.remove,
                          onTap: cols > minDim
                              ? () => _resize(rows, cols - 1)
                              : null,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('$cols',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        _circleBtn(
                          icon: Icons.add,
                          onTap: cols < maxDim
                              ? () => _resize(rows, cols + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Grid Input
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: List.generate(rows, (i) {
                    return Row(
                      children: List.generate(cols + 1, (j) {
                        final isResultCol = (j == cols);
                        return Container(
                          width: isResultCol ? 80 : 65,
                          margin: const EdgeInsets.all(4),
                          child: Column(
                            children: [
                              if (i == 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    isResultCol ? 'b' : 'x${j + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isResultCol
                                          ? Colors.red
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              TextFormField(
                                controller: controllers[i][j],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: isResultCol
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color:
                                      isResultCol ? Colors.red : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 12),
                                  isDense: true,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true, signed: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[-0-9.,/]+'))
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Action Button
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _onCalculateSPL,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text('HITUNG SOLUSI (SPL)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: _clearAll,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _circleBtn({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onTap != null ? Colors.deepPurple.shade50 : Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(
              color: onTap != null ? Colors.deepPurple : Colors.grey.shade300),
        ),
        child: Icon(icon,
            size: 20,
            color: onTap != null ? Colors.deepPurple : Colors.grey),
      ),
    );
  }

  Widget _buildSolutionCard() {
    return Card(
      elevation: 4,
      // ignore: deprecated_member_use
      shadowColor: Colors.deepPurple.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  'Hasil & Operasi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.deepPurple, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('Operasi Matriks A (Persegi):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: rows == cols ? _onCalculateDet : null,
                  icon: const Icon(Icons.functions, size: 18),
                  label: const Text('Determinan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: rows == cols ? _onCalculateInverse : null,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Invers Matriks'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            const Text('Hasil SPL (Ax = b):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildSolutionPreview(),
            ),

            const SizedBox(height: 16),
            const Text('Detail Langkah Pengerjaan SPL:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: obeSnapshots.isNotEmpty
                      ? () => _showOBEViewer(0)
                      : null,
                  icon: const Icon(Icons.format_list_numbered, size: 18),
                  label: const Text('Langkah OBE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: rows == cols ? _onShowLUSteps : null,
                  icon: const Icon(Icons.account_tree, size: 18),
                  label: const Text('Metode LU'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: solution.isNotEmpty ? _copySolutionCSV : null,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Salin x'),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const Text('Matriks RREF:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildRREFPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildSolutionPreview() {
    if (solution.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.calculate_outlined,
                size: 48, color: Colors.deepPurple.shade100),
            const SizedBox(height: 8),
            const Text('Belum ada solusi SPL',
                style: TextStyle(color: Colors.grey)),
            if (lastOperationLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(lastOperationLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              )
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lastOperationLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(lastOperationLabel,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green)),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(solution.length, (i) {
            return Container(
              width: 90,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.deepPurple.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                children: [
                  Text('x${i + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade300)),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(
                      solution[i].toStringAsFixed(precision),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRREFPreview() {
    final aug = _readAugmentedMatrix();
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            for (int i = 0; i < aug.length; i++)
              Row(
                children: [
                  for (int j = 0; j < aug[0].length; j++)
                    Container(
                      width: 50,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: j == cols ? Colors.red.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        aug[i][j].toStringAsFixed(precision),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            color: j == cols ? Colors.red : Colors.black87),
                      ),
                    )
                ],
              )
          ],
        ),
      ),
    );
  }

  void _showOBEViewer(int startIndex) {
    if (obeSnapshots.isEmpty) return;
    int idx = startIndex;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx2, setInner) {
          final snap = obeSnapshots[idx];
          final desc = obeDescriptions[idx];
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Langkah ${idx + 1}/${obeSnapshots.length}',
                    style: const TextStyle(fontSize: 16)),
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close))
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(desc,
                        style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      children: List.generate(snap.length, (i) {
                        return Row(
                          children: List.generate(snap[i].length, (j) {
                            return Container(
                              width: 60,
                              height: 40,
                              alignment: Alignment.center,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black12),
                                color: j == cols
                                    ? Colors.red.shade50
                                    : Colors.white,
                              ),
                              child: Text(
                                snap[i][j].toStringAsFixed(precision),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: j == cols
                                        ? FontWeight.bold
                                        : FontWeight.normal),
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: idx > 0 ? () => setInner(() => idx--) : null,
                  child: const Text('Sebelumnya')),
              ElevatedButton(
                  onPressed: idx < obeSnapshots.length - 1
                      ? () => setInner(() => idx++)
                      : null,
                  child: const Text('Berikutnya')),
            ],
          );
        });
      },
    );
  }

  void _copySolutionCSV() {
    if (solution.isEmpty) return;
    final csv = solution.map((v) => v.toStringAsFixed(precision)).join(',');
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Disalin ke clipboard!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      endDrawer: _buildSettingsDrawer(), // --- PERBAIKAN: MENAMBAHKAN DRAWER ---
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMatrixInputCard(),
            _buildSolutionCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}