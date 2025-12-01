import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/device_model.dart';
import '../mqtt_service.dart';
import '../services/firestore_service.dart';

class RgbColorPickerScreen extends StatefulWidget {
  final DeviceModel device;

  const RgbColorPickerScreen({Key? key, required this.device})
      : super(key: key);

  @override
  State<RgbColorPickerScreen> createState() => _RgbColorPickerScreenState();
}

class _RgbColorPickerScreenState extends State<RgbColorPickerScreen> {
  late MqttService _mqtt;
  late Color _currentColor;
  bool _isConnected = false;
  final _firestoreService = FirestoreService(useMockData: false);

  @override
  void initState() {
    super.initState();

    final rgb = widget.device.state.rgbColor!;
    _currentColor = Color.fromRGBO(rgb.r, rgb.g, rgb.b, 1.0);

    _mqtt = MqttService(
      broker: '83895141489f46ff87aeec52ea7f9f0d.s1.eu.hivemq.cloud',
      port: 8883,
      clientId: 'flutter_rgb_${widget.device.id}',
      username: 'dinhdat',
      password: '123Dd@456',
      onStatusChanged: (connected) {
        setState(() => _isConnected = connected);
      },
    );
    _mqtt.connect();
  }

  @override
  void dispose() {
    _mqtt.disconnect();
    super.dispose();
  }

  void _applyColor() {
    final r = _currentColor.red;
    final g = _currentColor.green;
    final b = _currentColor.blue;

    _mqtt.publish(
      topic: widget.device.topic,
      red: r,
      green: g,
      blue: b,
    );

    final newState = DeviceState.rgb(r: r, g: g, b: b);
    _firestoreService.updateDeviceState(
      widget.device.id,
      newState,
    );

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã áp dụng màu RGB($r, $g, $b)'),
        duration: const Duration(seconds: 1),
        backgroundColor: _currentColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Row(
                children: [
                  Text(_isConnected ? 'Đã kết nối' : 'Mất kết nối'),
                  const SizedBox(width: 8),
                  Icon(
                    _isConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: _isConnected ? Colors.greenAccent : Colors.redAccent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: _currentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _currentColor.withOpacity(0.5),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.lightbulb,
                  size: 100,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'RGB(${_currentColor.red}, ${_currentColor.green}, ${_currentColor.blue})',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text(
                      'Chọn màu sắc',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ColorPicker(
                      pickerColor: _currentColor,
                      onColorChanged: (Color color) {
                        setState(() {
                          _currentColor = color;
                        });
                      },
                      pickerAreaHeightPercent: 0.8,
                      enableAlpha: false,
                      displayThumbColor: true,
                      paletteType: PaletteType.hueWheel,
                      labelTypes: const [],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isConnected ? _applyColor : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentColor,
                  foregroundColor: _currentColor.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 32),
                    SizedBox(width: 12),
                    Text(
                      'Áp dụng màu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Màu sắc nhanh',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildPresetButton('Đỏ', Colors.red),
                _buildPresetButton('Xanh lá', Colors.green),
                _buildPresetButton('Xanh dương', Colors.blue),
                _buildPresetButton('Vàng', Colors.yellow),
                _buildPresetButton('Tím', Colors.purple),
                _buildPresetButton('Cam', Colors.orange),
                _buildPresetButton('Hồng', Colors.pink),
                _buildPresetButton('Trắng', Colors.white),
                _buildPresetButton('Tắt', Colors.black),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, Color color) {
    final textColor =
        color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _currentColor = color;
        });
        _applyColor();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(label),
    );
  }
}
