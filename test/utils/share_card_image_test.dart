import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music_life/utils/share_card_image.dart';

void main() {
  test('generateShareCardImage creates a non-empty PNG file', () async {
    final file = await generateShareCardImage(
      title: 'Practice Log',
      lines: ['2026/03', 'Practice days: 10', 'Total time: 300 min'],
    );

    final imageFile = File(file.path);
    expect(await imageFile.exists(), isTrue);
    expect(file.path.endsWith('.png'), isTrue);
    expect(await imageFile.length(), greaterThan(0));
  });
}
