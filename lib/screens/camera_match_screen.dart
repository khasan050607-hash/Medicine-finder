import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// This is the core AI feature — built in Phase 4 & 5
/// (embedding engine + live camera matching). Locked for now.
class CameraMatchScreen extends StatelessWidget {
  const CameraMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera দিয়ে খুঁজুন')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_front_outlined, size: 72, color: AppTheme.disabled),
              const SizedBox(height: 16),
              Text(
                'এই ফিচারটা পরের ধাপগুলোতে তৈরি হবে\n(ছবি ম্যাচিং ইঞ্জিন প্রয়োজন)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
