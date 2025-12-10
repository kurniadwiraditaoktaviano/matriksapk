// lib/MatrixUtils.dart
// ignore: unused_import
import 'dart:math';

class MatrixOps {
  static const double eps = 1e-12;

  /// Mengecek apakah matriks berbentuk persegi
  static bool isSquare(List<List<double>> A) =>
      A.isNotEmpty && A.length == A[0].length;

  /// Membuat deep copy dari matriks
  static List<List<double>> cloneMatrix(List<List<double>> A) =>
      A.map((r) => List<double>.from(r)).toList();

  // ==================== FITUR BARU ====================
  
  /// Transpose Matriks (Menukar Baris jadi Kolom)
  static List<List<double>> transpose(List<List<double>> A) {
    if (A.isEmpty) return [];
    final int r = A.length;
    final int c = A[0].length;
    return List.generate(c, (j) => List.generate(r, (i) => A[i][j]));
  }

  /// Perkalian Dua Matriks (A x B)
  /// Mengembalikan null jika ukuran tidak cocok (Kolom A != Baris B)
  static List<List<double>>? multiply(List<List<double>> A, List<List<double>> B) {
    if (A.isEmpty || B.isEmpty) return null;
    if (A[0].length != B.length) return null; // Syarat perkalian matriks

    final int r1 = A.length;
    final int c1 = A[0].length; // sama dengan B.length
    final int c2 = B[0].length;

    return List.generate(r1, (i) {
      return List.generate(c2, (j) {
        double sum = 0.0;
        for (int k = 0; k < c1; k++) {
          sum += A[i][k] * B[k][j];
        }
        return sum;
      });
    });
  }
  
  // ====================================================

  /// Mengembalikan determinan matriks persegi
  static double determinant(List<List<double>> A) {
    if (!isSquare(A)) throw ArgumentError('Matrix must be square');
    final n = A.length;
    final m = cloneMatrix(A);
    double det = 1.0;
    int swaps = 0;

    for (int i = 0; i < n; i++) {
      int pivot = i;
      for (int j = i + 1; j < n; j++) {
        if (m[j][i].abs() > m[pivot][i].abs()) pivot = j;
      }
      
      // Jika pivot 0, determinan pasti 0 (matriks singular)
      if (m[pivot][i].abs() < eps) return 0.0;

      if (pivot != i) {
        final tmp = m[i];
        m[i] = m[pivot];
        m[pivot] = tmp;
        swaps++;
      }

      final diag = m[i][i];
      det *= diag;

      for (int j = i + 1; j < n; j++) {
        m[i][j] /= diag;
      }

      for (int k = i + 1; k < n; k++) {
        final factor = m[k][i];
        for (int j = i + 1; j < n; j++) {
          m[k][j] -= factor * m[i][j];
        }
      }
    }

    if (swaps % 2 == 1) det = -det;
    return det;
  }

  /// Invers matriks menggunakan eliminasi Gauss-Jordan
  static List<List<double>>? inverse(List<List<double>> A) {
    if (!isSquare(A)) return null;
    final n = A.length;
    
    // Cek determinan dulu, jika 0 langsung return null agar lebih cepat
    // (Opsional, tapi praktik yang baik)
    if (determinant(A).abs() < eps) return null;

    final aug = List.generate(
        n, (i) => [...A[i], ...List.generate(n, (j) => i == j ? 1.0 : 0.0)]);

    for (int i = 0; i < n; i++) {
      int pivot = i;
      for (int j = i + 1; j < n; j++) {
        if (aug[j][i].abs() > aug[pivot][i].abs()) pivot = j;
      }
      if (aug[pivot][i].abs() < eps) return null;
      if (pivot != i) {
        final tmp = aug[i];
        aug[i] = aug[pivot];
        aug[pivot] = tmp;
      }

      final diag = aug[i][i];
      for (int j = 0; j < 2 * n; j++) {
        aug[i][j] /= diag;
      }

      for (int k = 0; k < n; k++) {
        if (k == i) continue;
        final factor = aug[k][i];
        for (int j = 0; j < 2 * n; j++) {
          aug[k][j] -= factor * aug[i][j];
        }
      }
    }

    return List.generate(n, (i) => aug[i].sublist(n));
  }

  /// Rank matriks (menggunakan RREF)
  static int rank(List<List<double>> A) {
    final rrefMat = rref(cloneMatrix(A));
    int rank = 0;
    for (var row in rrefMat) {
      if (row.any((v) => v.abs() > eps)) rank++;
    }
    return rank;
  }

  /// Menghasilkan bentuk eselon baris tereduksi (RREF)
  static List<List<double>> rref(List<List<double>> A) {
    final m = cloneMatrix(A);
    if (m.isEmpty) return m;
    final rowCount = m.length;
    final colCount = m[0].length;
    int lead = 0;

    for (int r = 0; r < rowCount; r++) {
      if (lead >= colCount) break;
      int i = r;
      while (i < rowCount && m[i][lead].abs() < eps) {
        i++;
      }
      if (i == rowCount) {
        lead++;
        r--;
        continue;
      }

      final tmp = m[r];
      m[r] = m[i];
      m[i] = tmp;

      final div = m[r][lead];
      if (div.abs() > eps) {
        for (int j = 0; j < colCount; j++) {
          m[r][j] /= div;
        }
      }

      for (int k = 0; k < rowCount; k++) {
        if (k == r) continue;
        final factor = m[k][lead];
        for (int j = 0; j < colCount; j++) {
          m[k][j] -= factor * m[r][j];
        }
      }
      lead++;
    }
    return m;
  }

  // --- LU & OBE Steps (Tidak berubah, biarkan kode lama Anda di sini) ---
  // (Pastikan Anda menyalin sisa kode luWithSteps dan luSolveToStringSteps
  // dari file MatrixUtils.dart yang lama agar fitur LU tetap jalan)
  
  static Map<String, dynamic> obeSolveWithSteps(
      List<List<double>> A, List<double> b) {
    final n = A.length;
    final aug = List.generate(n, (i) => [...A[i], b[i]]);
    final steps = <String>[];

    void record(String title) {
      steps.add('$title:\n${aug.map((r) => r.map((v) => v.toStringAsFixed(6)).join('\t')).join('\n')}');
    }

    record('Awal');

    for (int i = 0; i < n; i++) {
      int pivot = i;
      for (int j = i + 1; j < n; j++) {
        if (aug[j][i].abs() > aug[pivot][i].abs()) pivot = j;
      }
      if (aug[pivot][i].abs() < eps) continue;

      if (pivot != i) {
        final tmp = aug[i];
        aug[i] = aug[pivot];
        aug[pivot] = tmp;
        record('Swap baris $i dengan $pivot');
      }

      final diag = aug[i][i];
      for (int j = 0; j <= n; j++) {
        aug[i][j] /= diag;
      }
      record('Normalkan baris $i');

      for (int k = 0; k < n; k++) {
        if (k == i) continue;
        final factor = aug[k][i];
        for (int j = 0; j <= n; j++) {
          aug[k][j] -= factor * aug[i][j];
        }
      }
      record('Eliminasi kolom $i');
    }

    final solution = aug.map((r) => r.last).toList();
    record('Hasil akhir');
    return {'steps': steps, 'solution': solution};
  }

  static Map<String, dynamic>? luWithSteps(List<List<double>> A) {
    if (!isSquare(A)) return null;
    final n = A.length;
    List<List<double>> mat = List.generate(n, (i) => List.from(A[i]));
    List<int> pivot = List.generate(n, (i) => i);
    int pivotSign = 1;
    List<String> steps = [];

    void recordMatrix(String desc) {
      steps.add('$desc:\n${mat.map((r) => r.map((v) => v.toStringAsFixed(6)).join('\t')).join('\n')}');
    }

    recordMatrix('Matriks awal');

    for (int k = 0; k < n; k++) {
      int maxRow = k;
      double maxAbs = mat[k][k].abs();
      for (int i = k + 1; i < n; i++) {
        if (mat[i][k].abs() > maxAbs) {
          maxAbs = mat[i][k].abs();
          maxRow = i;
        }
      }

      steps.add(
          'Pivot kolom $k: nilai maksimum = ${maxAbs.toStringAsExponential(6)} pada baris $maxRow');

      if (maxRow != k) {
        final tmp = mat[k];
        mat[k] = mat[maxRow];
        mat[maxRow] = tmp;
        final tp = pivot[k];
        pivot[k] = pivot[maxRow];
        pivot[maxRow] = tp;
        pivotSign = -pivotSign;
        steps.add('Swap baris $k <-> $maxRow');
        recordMatrix('Setelah swap');
      }

      final pivotVal = mat[k][k];
      steps.add('Pivot = ${pivotVal.toStringAsExponential(6)}');

      for (int i = k + 1; i < n; i++) {
        double mult = 0.0;
        if (pivotVal.abs() > eps) {
          mat[i][k] /= pivotVal;
          mult = mat[i][k];
        }
        steps.add('Multiplier baris $i = ${mult.toStringAsFixed(6)}');
        for (int j = k + 1; j < n; j++) {
          mat[i][j] -= mult * mat[k][j];
        }
        recordMatrix('Eliminasi baris $i');
      }
    }

    List<List<double>> L = List.generate(n, (i) => List.filled(n, 0.0));
    List<List<double>> U = List.generate(n, (i) => List.filled(n, 0.0));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i > j) {
          L[i][j] = mat[i][j];
        } else if (i == j) {
          L[i][j] = 1.0;
          U[i][j] = mat[i][j];
        } else {
          U[i][j] = mat[i][j];
        }
      }
    }

    steps.add('Dekomposisi selesai.');
    return {
      'L': L,
      'U': U,
      'pivot': pivot,
      'pivotSign': pivotSign,
      'decompSteps': steps,
    };
  }

  static Map<String, dynamic> luSolveToStringSteps(
      List<List<double>> A, List<double> b) {
    final n = A.length;
    if (!isSquare(A) || b.length != n) {
      return {
        'solution': null,
        'decompositionSteps': ['Matrix A harus persegi dan ukuran b sesuai'],
        'forwardSteps': [],
        'backwardSteps': []
      };
    }

    final decomp = luWithSteps(A);
    if (decomp == null) {
      return {
        'solution': null,
        'decompositionSteps': ['Gagal dekomposisi LU'],
        'forwardSteps': [],
        'backwardSteps': []
      };
    }
    final L = (decomp['L'] as List<List<double>>);
    final U = (decomp['U'] as List<List<double>>);
    final pivot = (decomp['pivot'] as List<int>);
    final decompSteps = (decomp['decompSteps'] as List<String>);

    List<String> forwardSteps = [];
    List<String> backwardSteps = [];

    List<double> pb = List.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      pb[i] = b[pivot[i]];
    }
    forwardSteps.add('Terapkan pivot ke b: ${pb.map((v) => v.toStringAsFixed(6)).toList()}');

    List<double> y = List.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      double s = pb[i];
      String detail = 'y[$i] = pb[$i]';
      for (int j = 0; j < i; j++) {
        s -= L[i][j] * y[j];
        detail += ' - L[$i][$j]*y[$j]';
      }
      y[i] = s;
      forwardSteps.add('$detail = ${y[i].toStringAsFixed(6)}');
    }

    List<double> x = List.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      double s = y[i];
      String detail = 'x[$i] = (y[$i]';
      for (int j = i + 1; j < n; j++) {
        s -= U[i][j] * x[j];
        detail += ' - U[$i][$j]*x[$j]';
      }
      if (U[i][i].abs() < eps) {
        backwardSteps.add('Diagonal U[$i][$i] = 0, gagal.');
        return {
          'solution': null,
          'decompositionSteps': decompSteps,
          'forwardSteps': forwardSteps,
          'backwardSteps': backwardSteps
        };
      }
      x[i] = s / U[i][i];
      backwardSteps.add('$detail)/U[$i][$i] = ${x[i].toStringAsFixed(6)}');
    }

    return {
      'solution': x,
      'decompositionSteps': decompSteps,
      'forwardSteps': forwardSteps,
      'backwardSteps': backwardSteps
    };
  }
}