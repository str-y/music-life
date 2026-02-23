import 'package:flutter/material.dart';

class TunerScreen extends StatelessWidget {
  const TunerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('チューナー')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.tune,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('A4', style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 8),
              Text('440.0 Hz', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              Text(
                'マイク入力によるリアルタイム検出は今後対応予定です。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
