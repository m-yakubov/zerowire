import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'package:device_info_plus/device_info_plus.dart';

// ──────────────────────────────────────────────
// Discovery Service: UDP Multicast Device Radar
// ──────────────────────────────────────────────

/// Represents a discovered device on the local network.
class DiscoveredDevice {
  final String name;
  final String ip;
  final int port;
  final DateTime lastSeen;

  DiscoveredDevice({
    required this.name,
    required this.ip,
    required this.port,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  String get connectionString => 'http://$ip:$port/download';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice && ip == other.ip && port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

/// Manages UDP-based device discovery on the local network.
///
/// **Receiver side**: Broadcasts presence packets so senders can find them.
/// **Sender side**: Listens for receiver broadcasts and maintains a live device list.
class DiscoveryService extends ChangeNotifier {
  static const int _discoveryPort = 41234;
  static const String _magicPrefix = 'ZEROWIRE_V1';
  static const Duration _broadcastInterval = Duration(seconds: 2);
  static const Duration _deviceTimeout = Duration(seconds: 8);

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  Timer? _cleanupTimer;
  bool _isListening = false;
  bool _isBroadcasting = false;

  final List<DiscoveredDevice> _devices = [];
  String? _localIp;
  String _deviceName = 'Unknown Device';

  DiscoveryService() {
    _initDeviceName();
  }

  Future<void> _initDeviceName() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceName = iosInfo.name;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _deviceName = windowsInfo.computerName;
      }
    } catch (_) {
      _deviceName = Platform.localHostname;
    }
    // Capitalize manufacturer if needed
    if (_deviceName.isNotEmpty && _deviceName.contains(' ')) {
      final parts = _deviceName.split(' ');
      parts[0] = parts[0][0].toUpperCase() + parts[0].substring(1);
      _deviceName = parts.join(' ');
    }
    notifyListeners();
  }

  // ── Getters ──
  List<DiscoveredDevice> get devices => List.unmodifiable(_devices);
  bool get isListening => _isListening;
  bool get isBroadcasting => _isBroadcasting;
  String get deviceName => _deviceName;
  String get ipAddress => _localIp ?? '127.0.0.1';

  /// Set the device name for broadcasting.
  void setDeviceName(String name) {
    _deviceName = name;
    notifyListeners();
  }

  /// Resolves the device's local Wi-Fi IPv4 address.
  Future<String?> _getLocalIp() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) return wifiIp;
      for (var iface in await NetworkInterface.list()) {
        for (var addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ────────────────────────────────────────
  // SENDER SIDE: Listen for receiver beacons
  // ────────────────────────────────────────

  /// Start listening for receiver broadcasts on the network.
  Future<bool> startListening() async {
    if (_isListening) return true;

    try {
      _localIp = await _getLocalIp();
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );

      _socket!.broadcastEnabled = true;

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram == null) return;

          final message = utf8.decode(datagram.data);
          _handleReceivedMessage(message, datagram.address.address);
        }
      });

      // Periodically prune stale devices
      _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _pruneStaleDevices();
      });

      _isListening = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Discovery listen error: $e');
      return false;
    }
  }

  /// Stop listening for receiver broadcasts.
  void stopListening() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _socket?.close();
    _socket = null;
    _isListening = false;
    _devices.clear();
    notifyListeners();
  }

  /// Parse incoming UDP broadcast messages.
  void _handleReceivedMessage(String message, String senderIp) {
    if (!message.startsWith(_magicPrefix)) return;

    // Skip our own broadcasts
    if (senderIp == _localIp) return;

    try {
      // Format: ZEROWIRE_V1|RECEIVER|<name>|<port>
      final parts = message.split('|');
      if (parts.length < 4) return;
      if (parts[1] != 'RECEIVER') return;

      final name = parts[2];
      final port = int.tryParse(parts[3]) ?? 0;

      final device = DiscoveredDevice(
        name: name,
        ip: senderIp,
        port: port,
      );

      // Update or add
      final existingIndex = _devices.indexWhere(
        (d) => d.ip == senderIp && d.port == port,
      );

      if (existingIndex >= 0) {
        _devices[existingIndex] = device;
      } else {
        _devices.add(device);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Discovery parse error: $e');
    }
  }

  /// Remove devices not seen in the last [_deviceTimeout].
  void _pruneStaleDevices() {
    final now = DateTime.now();
    final before = _devices.length;
    _devices.removeWhere(
      (d) => now.difference(d.lastSeen) > _deviceTimeout,
    );
    if (_devices.length != before) {
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────
  // RECEIVER SIDE: Broadcast presence to senders
  // ──────────────────────────────────────────

  /// Start broadcasting this device's presence as a receiver.
  /// [serverPort] is the transfer server port the sender should connect to.
  Future<bool> startBroadcasting({int serverPort = 0}) async {
    if (_isBroadcasting) return true;

    try {
      _localIp = await _getLocalIp();

      _socket ??= await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket!.broadcastEnabled = true;

      // Send presence packet every 2 seconds
      _broadcastTimer = Timer.periodic(_broadcastInterval, (_) {
        _sendPresencePacket(serverPort);
      });

      // Send one immediately
      _sendPresencePacket(serverPort);

      _isBroadcasting = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Discovery broadcast error: $e');
      return false;
    }
  }

  /// Stop broadcasting presence.
  void stopBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _isBroadcasting = false;
    // Don't close the socket if we're also listening
    if (!_isListening) {
      _socket?.close();
      _socket = null;
    }
    notifyListeners();
  }

  /// Send a single presence packet to the broadcast address.
  void _sendPresencePacket(int serverPort) {
    if (_socket == null) return;

    final message = '$_magicPrefix|RECEIVER|$_deviceName|$serverPort';
    final data = utf8.encode(message);

    try {
      _socket!.send(
        data,
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );
    } catch (e) {
      debugPrint('Discovery send error: $e');
    }
  }

  @override
  void dispose() {
    stopListening();
    stopBroadcasting();
    super.dispose();
  }
}
