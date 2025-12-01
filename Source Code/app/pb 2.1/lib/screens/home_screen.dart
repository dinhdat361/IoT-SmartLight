import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/device_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'device_control_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService(useMockData: false);
  final _authService = AuthService(useMockAuth: false);
  List<DeviceModel> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      debugPrint('Loading devices for user: ${widget.user.email}');
      final devices = await _firestoreService.getUserDevices(widget.user.email);
      debugPrint('Found ${devices.length} devices');
      if (mounted) {
        setState(() {
          _devices = devices;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải thiết bị: $e')),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  String _getRoleDisplayName() {
    if (widget.user.isAdmin) return 'Admin';
    if (widget.user.isUser1) return 'User 1';
    if (widget.user.isUser2) return 'User 2';
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết Bị Của Tôi'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _getRoleDisplayName(),
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          widget.user.isAdmin ? Colors.amber : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadDevices,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return _buildDeviceCard(device);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Không có thiết bị nào',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Liên hệ Admin để cấp quyền hoặc',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initializeData,
            icon: const Icon(Icons.add_to_queue),
            label: const Text('Khởi tạo thiết bị mặc định'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.initializeSampleData(
          currentUserId: widget.user.uid);
      await _loadDevices();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã khởi tạo dữ liệu thành công!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildDeviceCard(DeviceModel device) {
    IconData icon;
    Color? color;
    String statusText;

    if (device.type == DeviceType.rgbLed) {
      icon = Icons.palette;
      final rgb = device.state.rgbColor!;
      color = Color.fromRGBO(rgb.r, rgb.g, rgb.b, 1.0);
      statusText =
          device.state.isOn ? 'RGB(${rgb.r}, ${rgb.g}, ${rgb.b})' : 'Tắt';
    } else {
      icon = device.name.toLowerCase().contains('đèn')
          ? Icons.lightbulb
          : Icons.air;
      color = device.state.isOn ? Colors.amber : Colors.grey.shade300;
      statusText = device.state.isOn ? 'Bật' : 'Tắt';
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DeviceControlScreen(
                device: device,
                user: widget.user,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: device.state.isOn
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color:
                      device.state.isOn ? Colors.white : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
