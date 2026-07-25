import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'search_screen.dart';
import 'add_medicine_screen.dart';
import 'medicine_list_screen.dart';
import 'camera_match_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine Finder')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
        children: [
          _ModuleCard(
            icon: Icons.search,
            label: 'Medicine খুঁজুন',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          _ModuleCard(
            icon: Icons.add_box_outlined,
            label: 'নতুন Medicine যোগ করুন',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
            ),
          ),
          _ModuleCard(
            icon: Icons.list_alt,
            label: 'সব Medicine দেখুন',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MedicineListScreen()),
            ),
          ),
          _ModuleCard(
            icon: Icons.camera_front_outlined,
            label: 'Camera দিয়ে খুঁজুন',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CameraMatchScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppTheme.primary),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
