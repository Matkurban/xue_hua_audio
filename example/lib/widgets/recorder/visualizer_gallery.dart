import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

import '../../models/visualizer_preset.dart';

/// Responsive grid displaying all 16 custom recording visualizers side-by-side
/// driven by the shared [WaveformController].
/// 全景预览网格：使用同一个 [WaveformController] 同屏实时渲染全部 16 款创新可视化组件。
class VisualizerGallery extends StatelessWidget {
  /// Creates a visualizer gallery grid. / 创建全景预览网格。
  const VisualizerGallery({
    super.key,
    required this.controller,
    required this.gradient,
    required this.selectedType,
    required this.onSelect,
  });

  /// Shared waveform controller. / 共享波形控制器。
  final WaveformController controller;

  /// Active gradient applied to each card. / 渐变配色。
  final Gradient gradient;

  /// Currently focused visualizer type. / 当前选中的组件类型。
  final RecordingVisualizerType selectedType;

  /// Callback when a gallery card is tapped. / 点击卡片切换主预览的回调。
  final ValueChanged<RecordingVisualizerType> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final customPresets = VisualizerPreset.all.skip(1).toList();
    return GridView.count(
      key: const ValueKey('visualizer-gallery-grid'),
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.05,
      children: [
        for (final preset in customPresets)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelect(preset.type),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: selectedType == preset.type
                    ? Border.all(color: scheme.primary, width: 1.5)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(preset.icon, size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${preset.title} · ${preset.subtitle}',
                          style: Theme.of(context).textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: RecordingVisualizer(
                      type: preset.type,
                      controller: controller,
                      height: 56,
                      gradient: gradient,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
