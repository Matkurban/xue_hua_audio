import 'package:material_ui/material_ui.dart';

import '../widgets/player/player_card.dart';
import '../widgets/recorder/recorder_card.dart';

/// Home page hosting the player and recorder demonstration cards.
/// 承载播放器与录音机演示卡片的主页面。
class HomePage extends StatelessWidget {
  /// Creates the home page. / 创建主页面。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('xue_hua_audio')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: const [PlayerCard(), SizedBox(height: 16), RecorderCard()],
      ),
    );
  }
}
