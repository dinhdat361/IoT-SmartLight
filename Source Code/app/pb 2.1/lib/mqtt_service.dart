import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  final String broker;
  final int port;
  final String username;
  final String password;
  late String clientId;
  late MqttServerClient _client;

  Function(bool)? onStatusChanged;

  MqttService({
    required this.broker,
    this.port = 8883,
    required String clientId,
    required this.username,
    required this.password,
    this.onStatusChanged,
  }) {
    var rng = Random();
    this.clientId = '${clientId}_${rng.nextInt(10000)}';

    _client = MqttServerClient(broker, this.clientId);
    _client.port = port;
    _client.logging(on: true); 
    _client.keepAlivePeriod = 60;
    _client.autoReconnect = true; 
    _client.setProtocolV311(); 

    _client.secure = true;
    _client.securityContext =
        SecurityContext.defaultContext; 
    _client.onBadCertificate =
        (dynamic cert) => true; // CHẤP NHẬN MỌI CHỨNG CHỈ

    _client.onConnected = onConnected;
    _client.onDisconnected = onDisconnected;
    _client.pongCallback = pong;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(this.clientId)
        .authenticateAs(username, password)
        .startClean(); 

    _client.connectionMessage = connMess;
  }

  Future<void> connect() async {
    try {
      debugPrint('⏳ Dang ket noi den HiveMQ (ID: $clientId)...');
      await _client.connect();

      if (_client.connectionStatus?.state == MqttConnectionState.connected) {
        debugPrint('✅ DA KET NOI THANH CONG! (State: Connected)');
        onStatusChanged?.call(true);
      } else {
        debugPrint(
            '❌ KET NOI THAT BAI (State: ${_client.connectionStatus?.state})');
        _client.disconnect();
        onStatusChanged?.call(false);
      }
    } on NoConnectionException catch (e) {
      debugPrint('❌ KET NOI THAT BAI - NoConnectionException: $e');
      _client.disconnect();
      onStatusChanged?.call(false);
    } on SocketException catch (e) {
      debugPrint('❌ KET NOI THAT BAI - SocketException: $e');
      _client.disconnect();
      onStatusChanged?.call(false);
    } catch (e) {
      debugPrint('❌ LOI KHAC: $e');
      _client.disconnect();
      onStatusChanged?.call(false);
    }
  }

  void disconnect() {
    _client.disconnect();
    onStatusChanged?.call(false);
  }

  void publish({
    required String topic,
    required int red,
    required int green,
    required int blue,
  }) {
    final payload = jsonEncode({
      'r': red,
      'g': green,
      'b': blue,
    });
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      debugPrint('📤 Da gui den $topic: $payload');
    } else {
      debugPrint('⚠️ Chua ket noi MQTT, khong the gui tin nhan!');
    }
  }

  void publishRelay({
    required String topic,
    required bool isOn,
  }) {
    final payload = jsonEncode({
      'state': isOn ? 'on' : 'off',
    });
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      debugPrint('📤 Da gui den $topic: $payload');
    } else {
      debugPrint('⚠️ Chua ket noi MQTT, khong the gui tin nhan!');
    }
  }

  void onConnected() {
    debugPrint('✅ DA KET NOI THANH CONG!');
    onStatusChanged?.call(true);
  }

  void onDisconnected() {
    debugPrint('❌ DA NGAT KET NOI.');
    onStatusChanged?.call(false);
  }

  void pong() => debugPrint('Ping response received');

  void subscribe(String topic, Function(String) onMessage) {
    _client.subscribe(topic, MqttQos.atLeastOnce);
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final recMess = messages[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      debugPrint('📥 Received from ${messages[0].topic}: $payload');
      onMessage(payload);
    });
  }

  void publishSchedule(String topic, Map<String, dynamic> scheduleData) {
    final payload = jsonEncode(scheduleData);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      debugPrint('📤 Da gui schedule den $topic: $payload');
    } else {
      debugPrint('⚠️ Chua ket noi MQTT, khong the gui schedule!');
    }
  }

  void publishAutomation(String topic, Map<String, dynamic> automationData) {
    final payload = jsonEncode(automationData);
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      debugPrint('📤 Da gui automation den $topic: $payload');
    } else {
      debugPrint('⚠️ Chua ket noi MQTT, khong the gui automation!');
    }
  }
}
