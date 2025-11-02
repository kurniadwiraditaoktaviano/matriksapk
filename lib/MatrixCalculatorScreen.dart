// lib/MatrixCalculatorScreen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

// Import MatrixUtils (MatrixOps) — pastikan lib/MatrixUtils.dart ada
import 'MatrixUtils.dart';

class MatrixCalculatorScreen extends StatefulWidget {
  const MatrixCalculatorScreen({super.key});

  @override
  State<MatrixCalculatorScreen> createState() => _MatrixCalculatorScreenState();
}

class _MatrixCalculatorScreenState extends State<MatrixCalculatorScreen> {
  int rows = 4, cols = 4;
  static const int maxDim = 6;
  static const int minDim = 1;

  late List<List<TextEditingController>> controllers;
  int precision = 2;

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
      (i) => List.generate(newCols + 1, (j) => TextEditingController(text: '0')),
    );

    for (int i = 0; i < min(newRows, oldR); i++) {
      for (int j = 0; j < min(newCols + 1, oldC); j++) {
        next[i][j].text = controllers[i][j].text;
      }
    }

    // dispose old controllers that are no longer used
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
    // safe read — ensure controllers shape is correct
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
      if (pivot.abs() < 1e-15) continue; // avoid dividing by (near) zero
      for (int j = c; j < m; j++) mat[r][j] /= pivot;
      _recordOBE(mat, 'Normalisasi baris $r (pivot di kolom $c dibuat 1)');

      for (int i = 0; i < n; i++) {
        if (i == r) continue;
        final factor = mat[i][c];
        if (factor.abs() < 1e-12) continue;
        for (int j = c; j < m; j++) mat[i][j] -= factor * mat[r][j];
        _recordOBE(mat, 'Eliminasi: gunakan baris $r untuk mengeliminasi entri pada baris $i');
      }

      r++;
    }

    // Check inconsistent rows
    for (int i = 0; i < n; i++) {
      bool allZero = true;
      for (int j = 0; j < cols; j++) if (mat[i][j].abs() > 1e-9) allZero = false;
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
          for (int cc = 0; cc < cols; cc++) if (cc != c && mat[i][cc].abs() > 1e-9) onlyPivot = false;
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
      lastOperationLabel = unique ? 'Solusi tunggal' : 'Solusi parametrik / banyak solusi';
    });
  }

  void _onCalculate() {
    _computeRREFAndSolution();
    if (obeSnapshots.isNotEmpty) _showOBEViewer(0);
  }

  void _clearAll() {
    for (var row in controllers) for (var c in row) c.text = '0';
    setState(() {
      solution = [];
      lastOperationLabel = '';
      obeSnapshots.clear();
      obeDescriptions.clear();
    });
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.deepPurple,
      title: const Text('Matrix Solver'),
      actions: [
        IconButton(
          onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          icon: const Icon(Icons.settings),
        )
      ],
    );
  }

  // ----------------- NEW: LU steps handler -----------------
  Future<void> _onShowLUSteps() async {
    if (rows != cols) {
      _showSnack('Untuk LU, matriks A harus persegi (rows == cols).');
      return;
    }

    final aug = _readAugmentedMatrix();

    // defensive check: ensure we have at least `cols` rows in aug
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
    final List<String> decompSteps = List<String>.from(res['decompositionSteps'] ?? []);
    final List<String> forwardSteps = List<String>.from(res['forwardSteps'] ?? []);
    final List<String> backwardSteps = List<String>.from(res['backwardSteps'] ?? []);
    final List<double>? sol = (res['solution'] != null) ? List<double>.from(res['solution']) : null;

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
                  const TabBar(tabs: [
                    Tab(text: 'Dekomposisi'),
                    Tab(text: 'Forward'),
                    Tab(text: 'Backward'),
                    Tab(text: 'Solusi'),
                  ]),
                  SizedBox(
                    height: 340,
                    child: TabBarView(children: [
                      _stepsListView(decompSteps),
                      _stepsListView(forwardSteps),
                      _stepsListView(backwardSteps),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: sol == null
                            ? const Text('Solusi tidak ditemukan atau matriks singular.')
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Solusi (${sol.length} variabel):', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: List.generate(sol.length, (i) {
                                        return Tooltip(
                                          message: sol[i].toString(),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.grey.shade100),
                                            child: Text('x${i + 1} = ${sol[i].toStringAsFixed(precision)}'),
                                          ),
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
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))
            ],
          ),
        );
      },
    );
  }

  Widget _stepsListView(List<String> steps) {
    if (steps.isEmpty) return const Text('Tidak ada langkah tersedia.');
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final s = steps[index];
        return Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SelectableText(s),
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

  // ----------------- UI Build -----------------
  Widget _buildMatrixInputCard() {
    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Input Matriks Diperluas ([A | B]):', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
            const SizedBox(width: 8),
            Row(children: [
              const Text('Baris:'),
              IconButton(onPressed: rows > minDim ? () => _resize(rows - 1, cols) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('$rows'),
              IconButton(onPressed: rows < maxDim ? () => _resize(rows + 1, cols) : null, icon: const Icon(Icons.add_circle_outline)),
              const SizedBox(width: 12),
              const Text('Kolom:'),
              IconButton(onPressed: cols > minDim ? () => _resize(rows, cols - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('$cols'),
              IconButton(onPressed: cols < maxDim ? () => _resize(rows, cols + 1) : null, icon: const Icon(Icons.add_circle_outline)),
            ])
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: List.generate(rows, (i) {
                return Row(
                  children: List.generate(cols + 1, (j) {
                    return Container(
                      width: j == cols ? 88 : 72,
                      margin: const EdgeInsets.all(6),
                      child: TextFormField(
                        controller: controllers[i][j],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,/]+'))],
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(onPressed: _onCalculate, icon: const Icon(Icons.calculate), label: const Text('HITUNG'), style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple)),
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: _clearAll, icon: const Icon(Icons.refresh), label: const Text('Reset')),
          ])
        ]),
      ),
    );
  }

  Widget _buildSolutionCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.layers_outlined, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text('Solusi Langkah-demi-Langkah', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(8)),
            child: _buildSolutionPreview(),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Detail Operasi Baris Elementer (OBE)', style: TextStyle(fontWeight: FontWeight.w600)),
            Row(children: [
              ElevatedButton.icon(onPressed: obeSnapshots.isNotEmpty ? () => _showOBEViewer(0) : null, icon: const Icon(Icons.playlist_play), label: const Text('Lihat Langkah')),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: rows == cols ? _onShowLUSteps : null, icon: const Icon(Icons.account_tree_outlined), label: const Text('Tampilkan Langkah LU')),
              const SizedBox(width: 8),
              ElevatedButton.icon(onPressed: solution.isNotEmpty ? _copySolutionCSV : null, icon: const Icon(Icons.copy), label: const Text('Copy Hasil')),
            ])
          ]),
          const SizedBox(height: 8),
          _buildRREFPreview(),
          const SizedBox(height: 12),
          ElevatedButton.icon(onPressed: _clearAll, icon: const Icon(Icons.refresh), label: const Text('Kalkulasi Matriks Baru'), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent)),
        ]),
      ),
    );
  }

  Widget _buildSolutionPreview() {
    if (solution.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Hasil Akhir (Presisi):', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 12, children: List.generate(cols, (i) {
          return Container(
            width: 80,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Column(children: [
              Text('x${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple)),
              const SizedBox(height: 6),
              Text('0.00', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green)),
            ]),
          );
        }))
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Hasil Akhir (Presisi):', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 12, children: List.generate(solution.length, (i) {
        return Tooltip(
          message: solution[i].toString(),
          child: Container(
            width: 100,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Column(children: [
              Text('x${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple)),
              const SizedBox(height: 6),
              SelectableText(solution[i].toStringAsFixed(precision), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.green)),
            ]),
          ),
        );
      }))
    ]);
  }

  Widget _buildRREFPreview() {
    final aug = _readAugmentedMatrix();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              for (int i = 0; i < aug.length; i++)
                Row(
                  children: [
                    for (int j = 0; j < aug[0].length; j++)
                      Container(
                        width: j == cols ? 84 : 64,
                        padding: const EdgeInsets.all(6),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(6), color: j == cols ? Colors.blue.shade50 : Colors.white),
                        child: Tooltip(message: aug[i][j].toString(), child: Text(aug[i][j].toStringAsFixed(precision), textAlign: TextAlign.center)),
                      )
                  ],
                )
            ],
          ),
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
            title: Text('Langkah ${idx + 1}/${obeSnapshots.length}'),
            content: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(desc, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: List.generate(snap.length, (i) {
                      return Row(
                        children: List.generate(snap[i].length, (j) {
                          return Container(
                            width: j == cols ? 84 : 64,
                            padding: const EdgeInsets.all(6),
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(6), color: j == cols ? Colors.blue.shade50 : Colors.white),
                            child: Tooltip(message: snap[i][j].toString(), child: Text(snap[i][j].toStringAsFixed(precision), textAlign: TextAlign.center)),
                          );
                        }),
                      );
                    }),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: idx > 0 ? () => setInner(() => idx--) : null, child: const Text('Prev')),
              TextButton(onPressed: idx < obeSnapshots.length - 1 ? () => setInner(() => idx++) : null, child: const Text('Next')),
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ],
          );
        });
      },
    );
  }

  void _copySolutionCSV() {
    if (solution.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada solusi untuk disalin')));
      return;
    }
    final csv = solution.map((v) => v.toStringAsFixed(precision)).join(',');
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hasil disalin ke clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 12),
          _buildMatrixInputCard(),
          const SizedBox(height: 8),
          _buildSolutionCard(),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}
