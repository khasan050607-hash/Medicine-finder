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
/// good enough once real medicine photos are tested, this is the one
/// file to swap for a TFLite model — everything else (database,
/// matching logic) stays the same because they only deal with
/// `List<double>` vectors, not how they were produced.
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
    return computeEmbeddingFromImage(decoded);
  }

  /// Same as [computeEmbedding] but works directly on an in-memory
  /// [img.Image] — used by the shelf scanner to fingerprint many
  /// cropped regions of one photo without writing a temp file per crop.
  static List<double> computeEmbeddingFromImage(img.Image image) {
    final resized = img.copyResize(image, width: 96, height: 96);

    final colorHist = _colorHistogram(resized);
    final brightnessGrid = _brightnessGrid(resized);

    final vector = [...colorHist, ...brightnessGrid];
    return _normalize(vector);
  }

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

  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }
}

class MatchResult {
  final int photoId;
  final int medicineId;
  final String imagePath;
  final String? label;
  final double score;

  MatchResult({
    required this.photoId,
    required this.medicineId,
    required this.imagePath,
    required this.label,
    required this.score,
  });
}

class SimilaritySearch {
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
