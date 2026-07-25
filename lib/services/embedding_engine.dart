import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/medicine.dart';

/// Turns a photo into a fixed-length numeric "fingerprint" (embedding)
/// that can be compared against other fingerprints for similarity.
///
/// NOTE ON APPROACH: a full deep-learning embedding (MobileNet/CLIP via
/// TFLite) gives noticeably better matching, but needs a .tflite model
/// file (tens of MB) downloaded from TensorFlow Hub or similar — this
/// build environment has no internet access to fetch one. So this
/// engine instead computes a classical computer-vision feature vector:
///
///   - a color histogram (captures the box's dominant colors)
///   - a coarse spatial brightness grid (captures rough shape/layout —
///     where the light/dark regions of the label sit)
///
/// This needs no external files, runs fully offline, and is good
/// enough to tell visually distinct boxes apart. If accuracy isn't
/// good enough once real medicine photos are tested (Task 11), this
/// is the one file to swap for a TFLite model — everything else
/// (database, matching logic) stays the same because they only deal
/// with `List<double>` vectors, not how they were produced.
class EmbeddingEngine {
  static const int _histBins = 8; // per color channel
  static const int _gridSize = 6; // 6x6 brightness grid

  /// Vector length: (8*3 color bins) + (6*6 brightness cells) = 60
  static const int vectorLength = (_histBins * 3) + (_gridSize * _gridSize);

  static Future<List<double>> computeEmbedding(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('ছবি পড়া যায়নি: $imagePath');
    }

    // Downscale first — we don't need full resolution for either
    // feature, and it makes this fast even on older phones.
    final resized = img.copyResize(decoded, width: 96, height: 96);

    final colorHist = _colorHistogram(resized);
    final brightnessGrid = _brightnessGrid(resized);

    final vector = [...colorHist, ...brightnessGrid];
    return _normalize(vector);
  }

  /// R/G/B histogram, [_histBins] buckets per channel, normalized by
  /// pixel count so it doesn't matter that box photos vary in size.
  static List<double> _colorHistogram(img.Image image) {
    final rBins = List<double>.filled(_histBins, 0);
    final gBins = List<double>.filled(_histBins, 0);
    final bBins = List<double>.filled(_histBins, 0);
    final bucketSize = 256 / _histBins;
    var total = 0;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        rBins[(pixel.r / bucketSize).floor().clamp(0, _histBins - 1)]++;
        gBins[(pixel.g / bucketSize).floor().clamp(0, _histBins - 1)]++;
        bBins[(pixel.b / bucketSize).floor().clamp(0, _histBins - 1)]++;
        total++;
      }
    }

    return [
      for (final v in rBins) v / total,
      for (final v in gBins) v / total,
      for (final v in bBins) v / total,
    ];
  }

  /// Average brightness of each cell in a [_gridSize] x [_gridSize]
  /// grid — a cheap stand-in for "rough shape/layout of the label",
  /// which helps tell apart boxes with similar colors but different
  /// text/logo placement.
  static List<double> _brightnessGrid(img.Image image) {
    final cellW = image.width / _gridSize;
    final cellH = image.height / _gridSize;
    final grid = List<double>.filled(_gridSize * _gridSize, 0);

    for (var gy = 0; gy < _gridSize; gy++) {
      for (var gx = 0; gx < _gridSize; gx++) {
        var sum = 0.0;
        var count = 0;
        final xStart = (gx * cellW).floor();
        final xEnd = ((gx + 1) * cellW).floor();
        final yStart = (gy * cellH).floor();
        final yEnd = ((gy + 1) * cellH).floor();

        for (var y = yStart; y < yEnd; y++) {
          for (var x = xStart; x < xEnd; x++) {
            final pixel = image.getPixel(x, y);
            // Standard luminance weighting.
            sum += 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
            count++;
          }
        }
        grid[gy * _gridSize + gx] = count > 0 ? (sum / count) / 255.0 : 0.0;
      }
    }
    return grid;
  }

  static List<double> _normalize(List<double> vector) {
    final magnitude = sqrt(vector.fold(0.0, (sum, v) => sum + v * v));
    if (magnitude == 0) return vector;
    return vector.map((v) => v / magnitude).toList();
  }

  /// Cosine similarity between two embeddings — 1.0 means identical
  /// direction (very similar), 0 means unrelated. Used by the
  /// matching logic in later tasks.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }
}

/// A single scored match returned by [SimilaritySearch].
class MatchResult {
  final int photoId;
  final int medicineId;
  final String imagePath;
  final String? label;
  final double score; // cosine similarity, -1..1 (higher = more similar)

  MatchResult({
    required this.photoId,
    required this.medicineId,
    required this.imagePath,
    required this.label,
    required this.score,
  });
}

/// Compares one query embedding (e.g. from a live camera frame)
/// against every stored embedding and ranks them by similarity.
/// Kept as a plain function over `List<double>` data so it doesn't
/// care whether embeddings came from the classical CV engine above
/// or a TFLite model swapped in later.
class SimilaritySearch {
  /// Returns the best matches sorted highest-score first. Pass
  /// [minScore] to filter out weak matches — the value 0.75 is a
  /// starting point and will likely need tuning once Task 11's
  /// real-photo testing shows what a "good" match actually scores.
  static List<MatchResult> search({
    required List<double> queryEmbedding,
    required List<StoredEmbedding> candidates,
    int topK = 5,
    double minScore = 0.0,
  }) {
    final scored = candidates.map((c) {
      final score = EmbeddingEngine.cosineSimilarity(queryEmbedding, c.embedding);
      return MatchResult(
        photoId: c.photoId,
        medicineId: c.medicineId,
        imagePath: c.imagePath,
        label: c.label,
        score: score,
      );
    }).where((m) => m.score >= minScore).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }
}

/// Lightweight carrier for a stored photo's embedding — kept separate
/// from the MedicinePhoto model so this file doesn't need to import
/// the database layer just to run a comparison. Other screens (e.g.
/// Camera Match) build a list of these from DBHelper query results.
class StoredEmbedding {
  final int photoId;
  final int medicineId;
  final String imagePath;
  final String? label;
  final List<double> embedding;

  StoredEmbedding({
    required this.photoId,
    required this.medicineId,
    required this.imagePath,
    required this.label,
    required this.embedding,
  });

  /// Converts DB rows to search candidates in one call, quietly
  /// skipping any photo that doesn't have an embedding yet (e.g. one
  /// saved before this feature existed, or where fingerprinting failed).
  static List<StoredEmbedding> fromMedicinePhotos(List<MedicinePhoto> photos) {
    return photos
        .where((p) => p.embedding != null && p.id != null)
        .map((p) => StoredEmbedding(
              photoId: p.id!,
              medicineId: p.medicineId,
              imagePath: p.imagePath,
              label: p.label,
              embedding: p.embedding!,
            ))
        .toList();
  }
}
