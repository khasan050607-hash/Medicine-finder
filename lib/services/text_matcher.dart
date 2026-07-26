import 'dart:math';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A place in the photo where OCR found text that matches (or nearly
/// matches) the medicine name we're searching for.
class TextHit {
  final Rect boundingBox;
  final String rawText;
  final double score; // 0..1, how well it matches the target name
  TextHit({required this.boundingBox, required this.rawText, required this.score});
}

class TextMatcher {
  static const double matchThreshold = 0.72;

  static Future<List<TextHit>> findNameMatches({
    required String imagePath,
    required String medicineName,
  }) async {
    final target = _normalize(medicineName);
    if (target.isEmpty) return [];

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    List<TextBlock> blocks;
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      blocks = recognized.blocks;
    } catch (_) {
      return [];
    } finally {
      await recognizer.close();
    }
    if (blocks.isEmpty) return [];

    final hits = <TextHit>[];
    final matchedBlockIndexes = <int>{};

    for (var i = 0; i < blocks.length; i++) {
      final normalized = _normalize(blocks[i].text);
      final score = _similarity(target, normalized);
      if (score >= matchThreshold) {
        hits.add(TextHit(boundingBox: blocks[i].boundingBox, rawText: blocks[i].text, score: score));
        matchedBlockIndexes.add(i);
      }
    }

    final remaining = [
      for (var i = 0; i < blocks.length; i++)
        if (!matchedBlockIndexes.contains(i)) i,
    ]..sort((a, b) => blocks[a].boundingBox.top.compareTo(blocks[b].boundingBox.top));

    for (var i = 0; i < remaining.length - 1; i++) {
      final a = blocks[remaining[i]];
      final b = blocks[remaining[i + 1]];
      final verticalGap = b.boundingBox.top - a.boundingBox.bottom;
      final avgHeight = (a.boundingBox.height + b.boundingBox.height) / 2;
      if (verticalGap < 0 || verticalGap > avgHeight * 0.8) continue;

      final combinedText = '${a.text} ${b.text}';
      final normalized = _normalize(combinedText);
      final score = _similarity(target, normalized);
      if (score >= matchThreshold) {
        hits.add(TextHit(
          boundingBox: a.boundingBox.expandToInclude(b.boundingBox),
          rawText: combinedText,
          score: score,
        ));
      }
    }

    hits.sort((x, y) => y.score.compareTo(x.score));
    return hits;
  }

  static String _normalize(String s) {
    return s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static double _similarity(String target, String candidate) {
    if (target.isEmpty || candidate.isEmpty) return 0.0;
    if (candidate.contains(target)) return 1.0;
    if (target.contains(candidate) && candidate.length >= target.length * 0.6) {
      return 0.9;
    }

    final winLen = target.length;
    if (candidate.length <= winLen) {
      final distance = _levenshtein(candidate, target);
      return (1 - distance / winLen).clamp(0.0, 1.0);
    }

    var best = 0.0;
    for (var i = 0; i + winLen <= candidate.length; i++) {
      final window = candidate.substring(i, i + winLen);
      final distance = _levenshtein(window, target);
      final ratio = 1 - distance / winLen;
      if (ratio > best) best = ratio;
    }
    return best.clamp(0.0, 1.0);
  }

  static int _levenshtein(String a, String b) {
    final la = a.length, lb = b.length;
    if (la == 0) return lb;
    if (lb == 0) return la;
    var prev = List<int>.generate(lb + 1, (j) => j);
    var curr = List<int>.filled(lb + 1, 0);

    for (var i = 1; i <= la; i++) {
      curr[0] = i;
      for (var j = 1; j <= lb; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = min(min(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[lb];
  }
}
