import 'dart:io';
import 'dart:ui' show Rect;
import 'package:image/image.dart' as img;
import 'embedding_engine.dart';
import 'text_matcher.dart';

class ScanMatch {
  final int x, y, width, height;
  final double score;
  final bool matchedByText;
  ScanMatch({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.score,
    this.matchedByText = false,
  });
}

class ShelfScanner {
  static Future<List<ScanMatch>> scan({
    required String photoPath,
    required List<StoredEmbedding> references,
    required String medicineName,
    int topN = 3,
  }) async {
    final bytes = await File(photoPath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null || references.isEmpty) return [];

    final textHits = await TextMatcher.findNameMatches(
      imagePath: photoPath,
      medicineName: medicineName,
    );

    final candidates = <ScanMatch>[];
    final fractions = [0.25, 0.35, 0.5];
    final shortSide = image.width < image.height ? image.width : image.height;

    for (final fraction in fractions) {
      final winSize = (shortSide * fraction).round();
      if (winSize < 20) continue;
      final stride = (winSize * 0.5).round().clamp(10, winSize);

      for (var y = 0; y + winSize <= image.height; y += stride) {
        for (var x = 0; x + winSize <= image.width; x += stride) {
          final crop = img.copyCrop(image, x: x, y: y, width: winSize, height: winSize);
          final embedding = EmbeddingEngine.computeEmbeddingFromImage(crop);

          var bestScore = -1.0;
          for (final ref in references) {
            final score = EmbeddingEngine.cosineSimilarity(embedding, ref.embedding);
            if (score > bestScore) bestScore = score;
          }

          final windowRect = Rect.fromLTWH(x.toDouble(), y.toDouble(), winSize.toDouble(), winSize.toDouble());
          final overlapsName = textHits.any((hit) => _overlapFraction(hit.boundingBox, windowRect) > 0.3);

          candidates.add(ScanMatch(
            x: x,
            y: y,
            width: winSize,
            height: winSize,
            score: overlapsName ? 1.0 : bestScore,
            matchedByText: overlapsName,
          ));
        }
      }
    }

    for (final hit in textHits) {
      final padX = hit.boundingBox.width * 0.6;
      final padY = hit.boundingBox.height * 1.5;
      final left = (hit.boundingBox.left - padX).clamp(0, image.width.toDouble());
      final top = (hit.boundingBox.top - padY).clamp(0, image.height.toDouble());
      final right = (hit.boundingBox.right + padX).clamp(0, image.width.toDouble());
      final bottom = (hit.boundingBox.bottom + padY).clamp(0, image.height.toDouble());
      candidates.add(ScanMatch(
        x: left.round(),
        y: top.round(),
        width: (right - left).round(),
        height: (bottom - top).round(),
        score: 1.0,
        matchedByText: true,
      ));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return _suppressOverlapping(candidates, topN);
  }

  static double _overlapFraction(Rect hit, Rect window) {
    final intersection = hit.intersect(window);
    if (intersection.width <= 0 || intersection.height <= 0) return 0.0;
    final hitArea = hit.width * hit.height;
    if (hitArea <= 0) return 0.0;
    return (intersection.width * intersection.height) / hitArea;
  }

  static List<ScanMatch> _suppressOverlapping(List<ScanMatch> sorted, int topN) {
    final kept = <ScanMatch>[];
    for (final candidate in sorted) {
      if (kept.length >= topN) break;
      final overlapsKept = kept.any((k) => _iou(candidate, k) > 0.3);
      if (!overlapsKept) kept.add(candidate);
    }
    return kept;
  }

  static double _iou(ScanMatch a, ScanMatch b) {
    final x1 = a.x > b.x ? a.x : b.x;
    final y1 = a.y > b.y ? a.y : b.y;
    final x2 = (a.x + a.width) < (b.x + b.width) ? (a.x + a.width) : (b.x + b.width);
    final y2 = (a.y + a.height) < (b.y + b.height) ? (a.y + a.height) : (b.y + b.height);
    final overlapW = (x2 - x1).clamp(0, a.width + b.width);
    final overlapH = (y2 - y1).clamp(0, a.height + b.height);
    final overlapArea = overlapW * overlapH;
    final unionArea = (a.width * a.height) + (b.width * b.height) - overlapArea;
    if (unionArea <= 0) return 0.0;
    return overlapArea / unionArea;
  }
}
