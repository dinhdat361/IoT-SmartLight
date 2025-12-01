import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/device_model.dart';
import '../models/user_model.dart';
import '../mqtt_service.dart';
import '../services/firestore_service.dart';

class DeviceControlScreen extends StatefulWidget {
  final DeviceModel device;
  final UserModel user;

  const DeviceControlScreen({
    Key? key,
    required this.device,
    required this.user,
  }) : super(key: key);

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  late MqttService _mqtt;
  late DeviceState _currentState;
  bool _isConnected = false;
  final _firestoreService = FirestoreService(useMockData: false);

  late double _red;
  late double _green;
  late double _blue;

  @override
  void initState() {
    super.initState();

    _currentState = widget.device.state;

    if (widget.device.type == DeviceType.rgbLed) {
      final rgb = widget.device.state.rgbColor!;
      _red = rgb.r.toDouble();
      _green = rgb.g.toDouble();
      _blue = rgb.b.toDouble();
    }

    _mqtt = MqttService(
      broker: '83895141489f46ff87aeec52ea7f9f0d.s1.eu.hivemq.cloud',
      port: 8883,
      clientId: 'flutter_${widget.device.id}',
      username: 'dinhdat',
      password: '123Dd@456',
      onStatusChanged: (connected) {
        if (mounted) {
          setState(() => _isConnected = connected);
          if (connected) {
            _subscribeToStatus();
          }
        }
      },
    );
    _mqtt.connect();
  }

  void _subscribeToStatus() {
    final parts = widget.device.topic.split('/');
    if (parts.isNotEmpty) {
      final statusTopic = '${parts[0]}/status';
      _mqtt.subscribe(statusTopic, _handleStatusMessage);
    }
  }

  void _handleStatusMessage(String payload) {
    try {
      final data = jsonDecode(payload);

      if (widget.device.type == DeviceType.relay) {
        if (data.containsKey(widget.device.id)) {
          final newStateStr = data[widget.device.id];
          final isOn = newStateStr == 'on';
          if (_currentState.isOn != isOn) {
            setState(() {
              _currentState = DeviceState.relay(isOn: isOn);
            });
          }
        }
      } else if (widget.device.type == DeviceType.rgbLed) {
        if (data.containsKey('rgb')) {
          final rgbData = data['rgb'];
          final r = rgbData['r'];
          final g = rgbData['g'];
          final b = rgbData['b'];

          setState(() {
            _red = (r as num).toDouble();
            _green = (g as num).toDouble();
            _blue = (b as num).toDouble();
            _currentState =
                DeviceState.rgb(r: r.toInt(), g: g.toInt(), b: b.toInt());
          });
        }
      }
    } catch (e) {
      debugPrint('Error parsing status: $e');
    }
  }

  @override
  void dispose() {
    _mqtt.disconnect();
    super.dispose();
  }

  void _toggleRelay(bool isOn) {
    if (widget.user.role == UserRole.user) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bạn không có quyền điều khiển thiết bị này')),
      );
      return;
    }

    setState(() {
      _currentState = DeviceState.relay(isOn: isOn);
    });

    _mqtt.publishRelay(
      topic: widget.device.topic,
      isOn: isOn,
    );

    _firestoreService.updateDeviceState(
      widget.device.id,
      _currentState,
    );
  }

  void _publishRGB() {
    if (widget.user.role == UserRole.user) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bạn không có quyền điều khiển thiết bị này')),
      );
      return;
    }

    final newState = DeviceState.rgb(
      r: _red.toInt(),
      g: _green.toInt(),
      b: _blue.toInt(),
    );

    setState(() {
      _currentState = newState;
    });

    _mqtt.publish(
      topic: widget.device.topic,
      red: _red.toInt(),
      green: _green.toInt(),
      blue: _blue.toInt(),
    );

    _firestoreService.updateDeviceState(
      widget.device.id,
      newState,
    );
  }

  Color get _currentColor {
    if (widget.device.type == DeviceType.rgbLed) {
      return Color.fromRGBO(_red.toInt(), _green.toInt(), _blue.toInt(), 1.0);
    }
    return _currentState.isOn ? Colors.amber : Colors.grey;
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
      body: widget.device.type == DeviceType.relay
          ? _buildRelayControl()
          : _buildRGBControl(),
    );
  }

  Widget _buildRelayControl() {
    final isOn = _currentState.isOn;
    final icon = widget.device.name.toLowerCase().contains('đèn')
        ? Icons.lightbulb
        : Icons.air;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: isOn ? Colors.amber : Colors.grey.shade300,
              shape: BoxShape.circle,
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 100,
              color: isOn ? Colors.white : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 40),

          // Status text
          Text(
            isOn ? 'ĐANG BẬT' : 'ĐANG TẮT',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isOn ? Colors.amber : Colors.grey,
            ),
          ),
          const SizedBox(height: 40),

          // Toggle button
          if (!_isConnected)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Đang kết nối thiết bị...',
                    style: TextStyle(color: Colors.grey)),
              ],
            )
          else
            SizedBox(
              width: 200,
              height: 60,
              child: ElevatedButton(
                onPressed: () => _toggleRelay(!isOn),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOn ? Colors.red : Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOn ? Icons.power_settings_new : Icons.power,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isOn ? 'TẮT' : 'BẬT',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRGBControl() {
    return SingleChildScrollView(
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
          if (!_isConnected)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Đang kết nối đến đèn RGB...',
                    style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            )
          else ...[
            Text(
              'RGB(${_red.toInt()}, ${_green.toInt()}, ${_blue.toInt()})',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            _buildColorSlider(
              label: 'Red',
              value: _red,
              color: Colors.red,
              onChanged: (value) {
                setState(() => _red = value);
                _publishRGB();
              },
            ),
            const SizedBox(height: 24),

            _buildColorSlider(
              label: 'Green',
              value: _green,
              color: Colors.green,
              onChanged: (value) {
                setState(() => _green = value);
                _publishRGB();
              },
            ),
            const SizedBox(height: 24),

            // BLUE Slider
            _buildColorSlider(
              label: 'Blue',
              value: _blue,
              color: Colors.blue,
              onChanged: (value) {
                setState(() => _blue = value);
                _publishRGB();
              },
            ),
            const SizedBox(height: 40),

            // Quick Color Buttons
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickColorButton('Đỏ', 255, 0, 0),
                _buildQuickColorButton('Xanh lá', 0, 255, 0),
                _buildQuickColorButton('Xanh dương', 0, 0, 255),
                _buildQuickColorButton('Vàng', 255, 255, 0),
                _buildQuickColorButton('Tím', 255, 0, 255),
                _buildQuickColorButton('Cyan', 0, 255, 255),
                _buildQuickColorButton('Trắng', 255, 255, 255),
                _buildQuickColorButton('Tắt', 0, 0, 0),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColorSlider({
    required String label,
    required double value,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              value.toInt().toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.3),
            thumbColor: color,
            overlayColor: color.withOpacity(0.2),
            trackHeight: 8,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            divisions: 255,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickColorButton(String label, int r, int g, int b) {
    final buttonColor = Color.fromRGBO(r, g, b, 1.0);
    final textColor = (r + g + b) > 384 ? Colors.black : Colors.white;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _red = r.toDouble();
          _green = g.toDouble();
          _blue = b.toDouble();
        });
        _publishRGB();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
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
