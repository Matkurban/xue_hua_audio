import 'package:material_ui/material_ui.dart';
import 'package:xue_hua_audio/xue_hua_audio.dart';

/// A dropdown that enumerates audio devices and applies the selection —
/// used for the player output device and the recorder input device.
/// 枚举音频设备并应用所选设备的下拉框——用于播放器输出设备与录音机输入设备。
class DeviceSelector extends StatefulWidget {
  /// Creates a device selector dropdown. / 创建设备选择下拉组件。
  const DeviceSelector({
    super.key,
    required this.icon,
    required this.label,
    required this.listDevices,
    required this.onSelected,
  });

  /// Leading icon. / 前置图标。
  final IconData icon;

  /// Dropdown label. / 下拉框标签。
  final String label;

  /// Enumerates the selectable devices. / 枚举可选设备。
  final Future<List<AudioDevice>> Function() listDevices;

  /// Applies the selection (`null` = system default).
  /// 应用所选设备（`null` 表示系统默认）。
  final Future<void> Function(String? deviceId) onSelected;

  @override
  State<DeviceSelector> createState() => _DeviceSelectorState();
}

class _DeviceSelectorState extends State<DeviceSelector> {
  List<AudioDevice> _devices = [];
  String? _selectedId;

  Future<void> _refresh() async {
    try {
      final devices = await widget.listDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        if (_selectedId != null && !devices.any((d) => d.id == _selectedId)) {
          _selectedId = null;
        }
      });
    } on AudioError catch (e) {
      _showError(e);
    }
  }

  Future<void> _select(String? deviceId) async {
    try {
      await widget.onSelected(deviceId);
      if (mounted) setState(() => _selectedId = deviceId);
    } on AudioError catch (e) {
      _showError(e);
    }
  }

  void _showError(AudioError error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(widget.icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: _selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.label,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('系统默认 System default'),
              ),
              for (final device in _devices)
                DropdownMenuItem<String?>(
                  value: device.id,
                  child: Text(device.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _select,
          ),
        ),
        IconButton(
          tooltip: '刷新设备列表 Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}
