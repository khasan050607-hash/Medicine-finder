import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../models/medicine.dart';
import 'photo_manager_screen.dart';

/// Full browse list of every medicine in the database, with edit
/// and delete built in. Pull-to-refresh isn't needed since we just
/// reload after any change.
class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  List<Medicine> _medicines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await DBHelper.instance.getAllMedicines();
    setState(() {
      _medicines = list;
      _loading = false;
    });
  }

  Future<void> _confirmDelete(Medicine medicine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ডিলিট করবেন?'),
        content: Text('"${medicine.name}" ডিলিট করা হলে এটার সাথে যুক্ত ছবিও মুছে যাবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ডিলিট করুন', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && medicine.id != null) {
      await DBHelper.instance.deleteMedicine(medicine.id!);
      _load();
    }
  }

  Future<void> _editMedicine(Medicine medicine) async {
    final nameController = TextEditingController(text: medicine.name);
    final shelfController = TextEditingController(text: medicine.shelf);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Medicine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'নাম'),
            ),
            TextField(
              controller: shelfController,
              decoration: const InputDecoration(labelText: 'Shelf'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সেভ করুন')),
        ],
      ),
    );

    if (saved == true) {
      final updated = Medicine(
        id: medicine.id,
        name: nameController.text.trim(),
        shelf: shelfController.text.trim(),
        category: medicine.category,
        createdAt: medicine.createdAt,
      );
      await DBHelper.instance.updateMedicine(updated);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('সব Medicine'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _medicines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.list_alt, size: 64, color: AppTheme.disabled),
                      const SizedBox(height: 12),
                      Text(
                        'এখনো কোনো Medicine যোগ করা হয়নি',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _medicines.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final medicine = _medicines[index];
                    return Card(
                      child: ListTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PhotoManagerScreen(medicine: medicine)),
                          );
                          _load();
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary.withOpacity(0.1),
                          child: const Icon(Icons.medication, color: AppTheme.primary),
                        ),
                        title: Text(medicine.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Shelf: ${medicine.shelf}  •  ছবি দেখতে/যোগ করতে ট্যাপ করুন'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editMedicine(medicine),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed: () => _confirmDelete(medicine),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
