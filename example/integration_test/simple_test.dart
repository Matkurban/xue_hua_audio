import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('instance throws before initialize', () {
    expect(() => XuehuaAudio.instance, throwsA(isA<StateError>()));
  });

  test('initialize is idempotent', () async {
    final first = await XuehuaAudio.initialize();
    final second = await XuehuaAudio.initialize();
    expect(identical(first, second), isTrue);
    expect(identical(first.engine, second.engine), isTrue);
    await first.dispose();
  });
}
