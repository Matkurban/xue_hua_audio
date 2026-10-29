// xue_hua_audio example entry point.
// Structured into modular folders: app.dart, theme/, models/, pages/, widgets/.
// xue_hua_audio 示例应用入口，按标准多文件目录结构拆分。
import 'package:material_ui/material_ui.dart';

import 'app.dart';

export 'app.dart';
export 'models/visualizer_preset.dart';
export 'pages/home_page.dart';
export 'theme/app_theme.dart';
export 'widgets/common/device_selector.dart';
export 'widgets/player/player_card.dart';
export 'widgets/recorder/recorder_card.dart';
export 'widgets/recorder/visualizer_gallery.dart';
export 'widgets/recorder/visualizer_selector.dart';

void main() {
  runApp(const ExampleApp());
}
