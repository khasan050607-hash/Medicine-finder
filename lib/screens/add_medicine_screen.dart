import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../models/medicine.dart';
import 'photo_manager_screen.dart';

/// Step 1: save name + shelf (creates the medicine row).
/// Step 2: once saved, jump into Photo Manager to add photos/video —
/// the same screen used later for adding new packaging versions to
/// existing medicines, so there's one capture flow instead of two.
class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shelfController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final name = _nameController.text.trim();
      final shelf = _shelfController.text.trim();
      final id = await DBHelper.instance.insertMedicine(Medicine(name: name, shelf: shelf));
      if (!mounted) return;

      setState(() => _saving = false);
      _nameController.clear();
      _shelfController.clear();

      // Straight into Photo Manager for this new medicine.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PhotoManagerScreen(
            medicine: Medicine(id: id, name: name, shelf: shelf),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('সেভ করতে সমস্যা হয়েছে, আবার চেষ্টা করুন')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shelfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('নতুন Medicine যোগ করুন')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Medicine এর নাম',
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'নাম লিখুন' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _shelfController,
                decoration: InputDecoration(
                  labelText: 'Shelf নম্বর',
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Shelf নম্বর লিখুন' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'সেভ হচ্ছে...' : 'সেভ করে ছবি যোগ করুন'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
