import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../database/db_helper.dart';
import '../models/medicine.dart';

/// Live search against the local database. Typing filters the list
/// on every keystroke (name LIKE query), so results update instantly.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine খুঁজুন')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              onChanged: _runSearch,
              decoration: InputDecoration(
                hintText: 'Medicine এর নাম লিখুন...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          _runSearch('');
                        },
                      )
                    : null,
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
      return _EmptyState(
        icon: Icons.medical_services_outlined,
        text: 'Medicine এর নাম লিখে খোঁজা শুরু করুন',
      );
    }
    if (_results.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off,
        text: 'কোনো Medicine পাওয়া যায়নি\nবানান চেক করুন বা নতুন করে যোগ করুন',
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
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.disabled),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
