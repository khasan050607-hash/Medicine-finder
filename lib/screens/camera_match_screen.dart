import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../models/medicine.dart';
import 'live_camera_screen.dart';

/// Step 1 of Camera Match: pick which medicine you're looking for.
/// Step 2 (live camera + matching) happens in LiveCameraScreen,
/// reached after a medicine is selected here.
class CameraMatchScreen extends StatefulWidget {
  const CameraMatchScreen({super.key});

  @override
  State<CameraMatchScreen> createState() => _CameraMatchScreenState();
}

class _CameraMatchScreenState extends State<CameraMatchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Medicine> _results = [];
  bool _loading = false;
  bool _hasSearched = false;

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    setState(() => _loading = true);
    final results = await DBHelper.instance.searchMedicines(query.trim());
    setState(() {
      _results = results;
      _loading = false;
      _hasSearched = true;
    });
  }

  Future<void> _openCameraFor(Medicine medicine) async {
    final photos = await DBHelper.instance.getPhotosForMedicine(medicine.id!);
    if (photos.where((p) => p.embedding != null).isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${medicine.name}"-এর কোনো ছবি এখনো যোগ করা হয়নি — আগে ছবি যোগ করুন'),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LiveCameraScreen(medicine: medicine)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera দিয়ে খুঁজুন')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'কোন Medicine খুঁজছেন?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              onChanged: _runSearch,
              decoration: InputDecoration(
                hintText: 'Medicine এর নাম লিখুন...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_front_outlined, size: 64, color: AppTheme.disabled),
            const SizedBox(height: 12),
            Text(
              'Medicine এর নাম লিখে সিলেক্ট করুন,\nতারপর ক্যামেরা খুলবে',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text('কোনো Medicine পাওয়া যায়নি', style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final medicine = _results[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: const Icon(Icons.medication, color: AppTheme.primary),
            ),
            title: Text(medicine.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Shelf: ${medicine.shelf}'),
            trailing: const Icon(Icons.camera_alt_outlined),
            onTap: () => _openCameraFor(medicine),
          ),
        );
      },
    );
  }
}
