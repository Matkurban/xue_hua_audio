import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('instance throws before initialize', () {
    expect(() => XueHuaAudio.instance, throwsA(isA<StateError>()));
  });

  test('initialize is idempotent', () async {
    final first = await XueHuaAudio.initialize();
    final second = await XueHuaAudio.initialize();
    expect(identical(first, second), isTrue);
    expect(identical(first.engine, second.engine), isTrue);
    await first.dispose();
  });
}
