import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

import '../../models/visualizer_preset.dart';

/// Interactive chip selector for switching across all 17 recording visualizer
/// presets and the classic [WaveformStyle] variants.
/// 交互式录音可视化选择器：支持在全部 17 种预设组件及经典波形子样式之间切换。
class VisualizerSelector extends StatelessWidget {
  /// Creates a visualizer selector. / 创建可视化选择器。
  const VisualizerSelector({
    super.key,
    required this.selectedType,
    required this.waveformStyle,
    required this.onTypeChanged,
    required this.onStyleChanged,
  });

  /// Currently selected visualizer preset type. / 当前选中的可视化组件类型。
  final RecordingVisualizerType selectedType;

  /// Currently selected sub-style for [AudioWaveform]. / 当前选中的经典波形样式。
  final WaveformStyle waveformStyle;

  /// Callback when a visualizer preset chip is tapped. / 切换可视化组件回调。
  final ValueChanged<RecordingVisualizerType> onTypeChanged;

  /// Callback when a classic waveform style is selected. / 切换经典波形样式回调。
  final ValueChanged<WaveformStyle> onStyleChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final preset in VisualizerPreset.all)
              ChoiceChip(
                key: ValueKey('vis-${preset.type.name}'),
                avatar: Icon(preset.icon, size: 16),
                label: Text(preset.title),
                selected: selectedType == preset.type,
                onSelected: (_) => onTypeChanged(preset.type),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<WaveformStyle>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: WaveformStyle.bars, label: Text('Bars')),
            ButtonSegment(value: WaveformStyle.line, label: Text('Line')),
            ButtonSegment(value: WaveformStyle.filled, label: Text('Filled')),
          ],
          selected: {waveformStyle},
          onSelectionChanged: (v) => onStyleChanged(v.first),
        ),
      ],
    );
  }
}
