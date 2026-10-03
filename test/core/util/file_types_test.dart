import 'package:flutter_test/flutter_test.dart';

import 'package:r16a_cloud_app/core/util/file_types.dart';

void main() {
  test('isImageFileName matches the web extension list, case-insensitive', () {
    for (final name in [
      'a.jpg',
      'a.JPEG',
      'a.png',
      'a.heic',
      'a.webp',
      'a.svg',
    ]) {
      expect(isImageFileName(name), isTrue, reason: name);
    }
    for (final name in ['a.tiff', 'a.pdf', 'jpg', 'a.jpg.txt']) {
      expect(isImageFileName(name), isFalse, reason: name);
    }
  });

  test('isVideoFileName matches the web extension list', () {
    expect(isVideoFileName('clip.MOV'), isTrue);
    expect(isVideoFileName('clip.mkv'), isTrue);
    expect(isVideoFileName('clip.wmv'), isFalse);
  });

  test('isHeicFileName', () {
    expect(isHeicFileName('IMG_1.HEIC'), isTrue);
    expect(isHeicFileName('IMG_1.heif'), isTrue);
    expect(isHeicFileName('IMG_1.jpg'), isFalse);
  });
}
