import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../theme/app_theme.dart';
import '../models/medicine.dart';
import '../database/db_helper.dart';
import '../services/embedding_engine.dart';
import '../services/shelf_scanner.dart';

class LiveCameraScreen extends StatefulWidget {
  final Medicine medicine;
  const LiveCameraScreen({super.key, required this.medicine});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  static const double _goodMatchThreshold = 0.90;

  final _picker = ImagePicker();
  List<StoredEmbedding> _referenceEmbeddings = [];
  bool _loadingRefs = true;

  String? _photoPath;
  int? _photoWidth;
  int? _photoHeight;
  List<ScanMatch> _matches = [];
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    final photos = await DBHelper.instance.getPhotosForMedicine(widget.medicine.id!);
    setState(() {
      _referenceEmbeddings = StoredEmbedding.fromMedicinePhotos(photos);
      _loadingRefs = false;
    });
  }

  Future<void> _takeShelfPhoto() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (xfile == null) return;

    setState(() {
      _scanning = true;
      _error = null;
      _matches = [];
      _photoPath = xfile.path;
    });

    try {
      final bytes = await File(xfile.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('ছবি পড়া যায়নি');

      final results = await ShelfScanner.scan(
        photoPath: xfile.path,
        references: _referenceEmbeddings,
        topN: 3,
      );

      setState(() {
        _photoWidth = decoded.width;
        _photoHeight = decoded.height;
        _matches = results;
        _scanning = false;
      });
    } catch (e) {
      setState(() {
        _error = 'ছবি বিশ্লেষণ করতে সমস্যা হয়েছে, আবার চেষ্টা করুন';
        _scanning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('খুঁজছেন: ${widget.medicine.name}'),
        backgroundColor: AppTheme.primaryDark,
      ),
      body: _buildBody(),
      floatingActionButton: _loadingRefs || _referenceEmbeddings.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _scanning ? null : _takeShelfPhoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(_photoPath == null ? 'শেলফের ছবি তুলুন' : 'আবার তুলুন'),
              backgroundColor: AppTheme.primary,
            ),
    );
  }

  Widget _buildBody() {
    if (_loadingRefs) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_referenceEmbeddings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_library_outlined, size: 56, color: Colors.white54),
              const SizedBox(height: 12),
              const Text(
                'এই মেডিসিনের কোনো ছবি এখনো যোগ করা হয়নি',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    if (_photoPath == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'নিচের বাটনে চেপে পুরো শেলফের একটা ছবি তুলুন —\nআমরা সেখানে সবচেয়ে মিল থাকা জায়গা খুঁজে দেখাব',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    if (_scanning) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('ছবি বিশ্লেষণ করা হচ্ছে...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)));
    }

    if (_photoWidth == null || _photoHeight == null) {
      return const SizedBox.shrink();
    }

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final aspectRatio = _photoWidth! / _photoHeight!;
          final maxW = constraints.maxWidth;
          final maxH = constraints.maxHeight;
          double displayW, displayH;
          if (maxW / maxH > aspectRatio) {
            displayH = maxH;
            displayW = displayH * aspectRatio;
          } else {
            displayW = maxW;
            displayH = displayW / aspectRatio;
          }

          return SizedBox(
            width: displayW,
            height: displayH,
            child: Stack(
              children: [
                Positioned.fill(child: Image.file(File(_photoPath!), fit: BoxFit.cover)),
                ..._buildMatchBoxes(displayW, displayH),
                if (_matches.isEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: _statusChip('ভালো কোনো মিল পাওয়া যায়নি — কাছাকাছি গিয়ে আবার তুলুন', Colors.orangeAccent),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildMatchBoxes(double displayW, double displayH) {
    if (_photoWidth == null || _photoHeight == null) return [];
    final widgets = <Widget>[];

    for (var i = 0; i < _matches.length; i++) {
      final match = _matches[i];
      final isBest = i == 0;
      final isGood = match.score >= _goodMatchThreshold;
      if (!isBest && match.score < _goodMatchThreshold) continue;

      final left = (match.x / _photoWidth!) * displayW;
      final top = (match.y / _photoHeight!) * displayH;
      final boxW = (match.width / _photoWidth!) * displayW;
      final boxH = (match.height / _photoHeight!) * displayH;
      final color = isBest && isGood ? Colors.greenAccent : Colors.orangeAccent;

      widgets.add(
        Positioned(
          left: left,
          top: top,
          width: boxW,
          height: boxH,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      );

      if (isBest) {
        widgets.add(
          Positioned(
            left: left,
            top: (top - 22).clamp(0, displayH),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: color,
              child: Text(
                '${((match.score + 1) / 2 * 100).clamp(0, 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 13), textAlign: TextAlign.center),
    );
  }
}
