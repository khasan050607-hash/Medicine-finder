import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Turns a short video (recorded while rotating the medicine box) into
/// a handful of still frames, spaced evenly across its length. This
/// replaces manually taking 4+ separate photos per box — one ~10 second
/// video covering all sides is enough.
class FrameExtractor {
  /// Extracts [frameCount] frames from the video at [videoPath], saves
  /// them as JPEGs under the app's medicine_photos folder, and returns
  /// their file paths. Frames are spaced evenly from the video's start
  /// to its end (never exactly at 0 or the very last ms, so we avoid
  /// black/blank frames some cameras write at the boundaries).
  static Future<List<String>> extractFrames({
    required String videoPath,
    required int medicineId,
    int frameCount = 8,
  }) async {
    final durationMs = await _getDurationMs(videoPath);
    if (durationMs <= 0) return [];

    final appDir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(appDir.path, 'medicine_photos'));
    if (!await outDir.exists()) await outDir.create(recursive: true);

    final paths = <String>[];
    // Skip the very first/last 5% of the clip — that's usually the
    // hand moving the box into frame or pulling the camera away.
    final start = (durationMs * 0.05).round();
    final end = (durationMs * 0.95).round();
    final step = (end - start) / (frameCount - 1);

    for (var i = 0; i < frameCount; i++) {
      final timeMs = (start + step * i).round();
      try {
        final thumbPath = await vt.VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: outDir.path,
          imageFormat: vt.ImageFormat.JPEG,
          timeMs: timeMs,
          quality: 85,
        );
        if (thumbPath == null) continue;

        // video_thumbnail names files unpredictably — rename to something
        // consistent and tied to this medicine so we can find it later.
        final finalName = 'med${medicineId}_vidframe_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final finalPath = p.join(outDir.path, finalName);
        await File(thumbPath).rename(finalPath);
        paths.add(finalPath);
      } catch (_) {
        // One bad frame shouldn't stop the rest of the extraction.
        continue;
      }
    }
    return paths;
  }

  static Future<int> _getDurationMs(String videoPath) async {
    final controller = VideoPlayerController.file(File(videoPath));
    try {
      await controller.initialize();
      return controller.value.duration.inMilliseconds;
    } catch (_) {
      return 0;
    } finally {
      await controller.dispose();
    }
  }
}
