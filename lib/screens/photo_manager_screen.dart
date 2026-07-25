import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../models/medicine.dart';
import '../services/frame_extractor.dart';
import '../services/embedding_engine.dart';

/// Opened by tapping a medicine in the list, or right after adding a
/// new one. Lets you keep adding photos over time — including a new
/// "packaging version" when a company changes box colors/design, so
/// both old and new designs stay recognizable instead of the old
/// photos becoming dead weight.
class PhotoManagerScreen extends StatefulWidget {
  final Medicine medicine;
  const PhotoManagerScreen({super.key, required this.medicine});

  @override
  State<PhotoManagerScreen> createState() => _PhotoManagerScreenState();
}

class _PhotoManagerScreenState extends State<PhotoManagerScreen> {
  static const List<String> _versionOptions = ['স্ট্যান্ডার্ড', 'পুরনো প্যাকেজিং', 'নতুন প্যাকেজিং'];

  final _picker = ImagePicker();
  List<MedicinePhoto> _photos = [];
  bool _loading = true;
  bool _capturing = false;
  String _selectedVersion = _versionOptions.first;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final photos = await DBHelper.instance.getPhotosForMedicine(widget.medicine.id!);
    setState(() {
      _photos = photos;
      _loading = false;
    });
  }

  Future<Directory> _photosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'medicine_photos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _takePhoto() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (xfile == null) return;

    setState(() => _capturing = true);
    try {
      final dir = await _photosDir();
      final fileName = 'med${widget.medicine.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(dir.path, fileName);
      await File(xfile.path).copy(savedPath);

      List<double>? embedding;
      try {
        embedding = await EmbeddingEngine.computeEmbedding(savedPath);
      } catch (_) {
        // If the fingerprint fails to compute, we still keep the
        // photo — it just won't be matchable via Camera Match yet.
      }

      await DBHelper.instance.insertPhoto(
        MedicinePhoto(
          medicineId: widget.medicine.id!,
          imagePath: savedPath,
          label: _selectedVersion,
          embedding: embedding,
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ছবি সেভ করতে সমস্যা হয়েছে')),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _recordVideo() async {
    final xfile = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 15));
    if (xfile == null) return;
    if (!mounted) return;

    setState(() => _capturing = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Expanded(child: Text('ভিডিও থেকে ছবি বের করা হচ্ছে...')),
          ],
        ),
      ),
    );

    try {
      final framePaths = await FrameExtractor.extractFrames(
        videoPath: xfile.path,
        medicineId: widget.medicine.id!,
        frameCount: 8,
      );
      for (final path in framePaths) {
        List<double>? embedding;
        try {
          embedding = await EmbeddingEngine.computeEmbedding(path);
        } catch (_) {
          // Keep the frame even if fingerprinting fails on it.
        }
        await DBHelper.instance.insertPhoto(
          MedicinePhoto(
            medicineId: widget.medicine.id!,
            imagePath: path,
            label: _selectedVersion,
            embedding: embedding,
          ),
        );
      }
      await _load();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ভিডিও থেকে ${framePaths.length}টা ছবি যোগ করা হয়েছে')),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ভিডিও প্রসেস করতে সমস্যা হয়েছে')),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _deletePhoto(MedicinePhoto photo) async {
    if (photo.id == null) return;
    await DBHelper.instance.deletePhoto(photo.id!);
    try {
      final file = File(photo.imagePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    await _load();
  }

  /// Groups photos by their version label so old and new packaging
  /// (or plain "standard" photos) show as clearly separate sets.
  Map<String, List<MedicinePhoto>> get _grouped {
    final map = <String, List<MedicinePhoto>>{};
    for (final photo in _photos) {
      final key = photo.label ?? 'স্ট্যান্ডার্ড';
      map.putIfAbsent(key, () => []).add(photo);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.medicine.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Shelf: ${widget.medicine.shelf}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Divider(height: 28),
                  Text('নতুন ছবি কোন ভার্সনের?', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'কোম্পানি বক্সের রং/ডিজাইন বদলালে "নতুন প্যাকেজিং" বেছে ছবি যোগ করুন —\n'
                    'পুরনো ছবিও থেকে যাবে, দুটোই চেনা যাবে',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _versionOptions.map((v) {
                      final selected = v == _selectedVersion;
                      return ChoiceChip(
                        label: Text(v),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedVersion = v),
                        selectedColor: AppTheme.primary.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: selected ? AppTheme.primary : AppTheme.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _capturing ? null : _takePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('ছবি তুলুন'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _capturing ? null : _recordVideo,
                          icon: const Icon(Icons.videocam_outlined),
                          label: const Text('ভিডিও'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  if (_photos.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.photo_library_outlined, size: 48, color: AppTheme.disabled),
                          const SizedBox(height: 8),
                          Text('এখনো কোনো ছবি যোগ করা হয়নি', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ..._grouped.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.key} (${entry.value.length}টা ছবি)',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.value.map((photo) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        File(photo.imagePath),
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => _deletePhoto(photo),
                                        child: const CircleAvatar(
                                          radius: 11,
                                          backgroundColor: Colors.black54,
                                          child: Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
