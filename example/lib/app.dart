import 'package:material_ui/material_ui.dart';

import 'pages/home_page.dart';
import 'theme/app_theme.dart';

/// Root widget of the `xue_hua_audio` example application.
/// `xue_hua_audio` 示例应用的根组件。
class ExampleApp extends StatelessWidget {
  /// Creates the example app. / 创建示例应用。
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xue_hua_audio demo',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}
