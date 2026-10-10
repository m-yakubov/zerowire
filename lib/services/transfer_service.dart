import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_scanner/media_scanner.dart';

// ──────────────────────────────────────────────
// Transfer Service: Multi-File P2P Engine
// ──────────────────────────────────────────────

/// Manages the local HTTP file server (sender) and the download client (receiver).
/// Now supports multi-file queued transfers.
class TransferService extends ChangeNotifier {
  // ── Sender state ──
  HttpServer? _server;
  String? _localIp;
  int _port = 0;
  final List<File> _selectedFiles = [];
  final List<String> _selectedFileNames = [];
  final List<int> _selectedFileSizes = [];
  bool _isBroadcasting = false;
  int _downloadCount = 0;

  // ── Receiver state ──
  bool _isDownloading = false;
  double _downloadProgress = 0.0;      // Overall progress (0.0 - 1.0)
  double _currentFileProgress = 0.0;   // Current file progress
  String? _downloadedFilePath;
  String? _downloadFileName;
  String? _downloadError;
  bool _downloadComplete = false;
  int _totalFilesToReceive = 0;
  int _currentFileIndex = 0;
  final List<String> _receivedFiles = [];

  // ── Transfer history ──
  final List<TransferRecord> _history = [];

  // ── Connected Peers (Sender) ──
  final Set<String> _connectedPeers = {};

  Timer? _speedTimer;
  double _currentSpeedMBps = 0.0;
  String _eta = "--:--";
  final List<double> _speedHistory = [];
  int _totalBytesToTransfer = 0;
  int _totalBytesTransferred = 0;

  // ── Receiver incoming request server
  HttpServer? _receiverServer;
  int _receiverPort = 0;
  int get receiverPort => _receiverPort;

  // ── Getters ──
  bool get isBroadcasting => _isBroadcasting;
  String? get localIp => _localIp;
  int get port => _port;
  List<File> get selectedFiles => List.unmodifiable(_selectedFiles);
  List<String> get selectedFileNames => List.unmodifiable(_selectedFileNames);
  List<int> get selectedFileSizes => List.unmodifiable(_selectedFileSizes);
  int get selectedFileCount => _selectedFiles.length;
  Set<String> get connectedPeers => Set.unmodifiable(_connectedPeers);
  int get totalSelectedSize => _selectedFileSizes.fold(0, (a, b) => a + b);
  int get downloadCount => _downloadCount;
  String get connectionString => 'http://$_localIp:$_port';

  // Legacy single-file compat
  File? get selectedFile => _selectedFiles.isNotEmpty ? _selectedFiles.first : null;
  String? get selectedFileName => _selectedFileNames.isNotEmpty ? _selectedFileNames.first : null;
  int? get selectedFileSize => _selectedFileSizes.isNotEmpty ? _selectedFileSizes.first : null;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  double get currentFileProgress => _currentFileProgress;
  String? get downloadedFilePath => _downloadedFilePath;
  String? get downloadFileName => _downloadFileName;
  String? get downloadError => _downloadError;
  bool get downloadComplete => _downloadComplete;
  int get totalFilesToReceive => _totalFilesToReceive;
  int get currentFileIndex => _currentFileIndex;
  List<String> get receivedFiles => List.unmodifiable(_receivedFiles);

  List<TransferRecord> get history => List.unmodifiable(_history);

  // Analytics getters
  double get currentSpeedMBps => _currentSpeedMBps;
  String get eta => _eta;
  List<double> get speedHistory => List.unmodifiable(_speedHistory);

  void _startAnalyticsTimer(int totalBytes) {
    _totalBytesToTransfer = totalBytes;
    _totalBytesTransferred = 0;
    _currentSpeedMBps = 0.0;
    _eta = "--:--";
    _speedHistory.clear();
    for(int i = 0; i < 30; i++) {
      _speedHistory.add(0.0);
    }
    int lastTotal = 0;
    _speedTimer?.cancel();
    _speedTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_totalBytesToTransfer > 0) {
        int delta = _totalBytesTransferred - lastTotal;
        lastTotal = _totalBytesTransferred;
        
        // Calculate speed for the last half second (bytes/500ms * 2 = bytes/sec)
        double bytesPerSec = delta * 2.0;
        _currentSpeedMBps = bytesPerSec / (1024 * 1024);
        
        _speedHistory.removeAt(0);
        _speedHistory.add(_currentSpeedMBps);

        if (_currentSpeedMBps > 0) {
          int remainingBytes = _totalBytesToTransfer - _totalBytesTransferred;
          if (remainingBytes > 0) {
            double secondsRemaining = remainingBytes / bytesPerSec;
            if (secondsRemaining.isFinite) {
              int minutes = (secondsRemaining / 60).floor();
              int seconds = (secondsRemaining % 60).floor();
              _eta = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
            }
          } else {
             _eta = "00:00";
          }
        }
        
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  void _stopAnalyticsTimer() {
    _speedTimer?.cancel();
    _speedTimer = null;
    _currentSpeedMBps = 0.0;
    _eta = "--:--";
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

  // ──────────────────────────────────────────
  // SENDER: Multi-file HTTP Server
  // ──────────────────────────────────────────

  /// Starts the local HTTP server to serve selected files.
  /// Accepts a list of files for multi-file transfer.
  Future<bool> startServer(List<File> files) async {
    _selectedFiles.clear();
    _selectedFileNames.clear();
    _selectedFileSizes.clear();
    _downloadCount = 0;

    for (final file in files) {
      _selectedFiles.add(file);
      _selectedFileNames.add(file.path.split(Platform.pathSeparator).last);
      _selectedFileSizes.add(await file.length());
    }

    _localIp = await _getLocalIp();
    if (_localIp == null) return false;

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);

    try {
      _server = await shelf_io.serve(handler, '0.0.0.0', 0);
      _port = _server!.port;
      _isBroadcasting = true;
      int totalSize = _selectedFileSizes.fold(0, (a, b) => a + b);
      _startAnalyticsTimer(totalSize);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Server start error: $e');
      return false;
    }
  }

  /// Legacy single-file compat: wraps into multi-file call.
  Future<bool> startServerSingle(File file) async {
    return startServer([file]);
  }

  /// Handles incoming HTTP requests from the receiver.
  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final path = request.url.path;

    // Track peer IP
    try {
      final connInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
      if (connInfo != null) {
        final ip = connInfo.remoteAddress.address;
        if (!_connectedPeers.contains(ip)) {
          _connectedPeers.add(ip);
          notifyListeners();
        }
      }
    } catch (_) {}

    // ── /info — Returns JSON array of all files ──
    if (path == 'info') {
      final filesInfo = List.generate(_selectedFiles.length, (i) => {
        'index': i,
        'name': _selectedFileNames[i],
        'size': _selectedFileSizes[i],
      });
      return shelf.Response.ok(
        jsonEncode({'files': filesInfo, 'count': _selectedFiles.length}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // ── /download/<index> — Download a specific file by index ──
    final downloadMatch = RegExp(r'^download/(\d+)$').firstMatch(path);
    if (downloadMatch != null) {
      final index = int.parse(downloadMatch.group(1)!);
      if (index < 0 || index >= _selectedFiles.length) {
        return shelf.Response.notFound('File index out of range');
      }

      _downloadCount++;
      notifyListeners();

      final file = _selectedFiles[index];
      final stream = file.openRead().transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
             _totalBytesTransferred += data.length;
             sink.add(data);
          },
        ),
      );
      final length = await file.length();

      return shelf.Response.ok(
        stream,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="${_selectedFileNames[index]}"',
          'Content-Length': '$length',
        },
      );
    }

    // ── /download — Legacy single file (first file) ──
    if (path == 'download' && _selectedFiles.isNotEmpty) {
      _downloadCount++;
      notifyListeners();

      final file = _selectedFiles.first;
      final stream = file.openRead().transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
             _totalBytesTransferred += data.length;
             sink.add(data);
          },
        ),
      );
      final length = await file.length();

      return shelf.Response.ok(
        stream,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="${_selectedFileNames.first}"',
          'Content-Length': '$length',
        },
      );
    }

    return shelf.Response.notFound('Not found');
  }

  /// Stops the local HTTP server.
  Future<void> stopServer() async {
    _stopAnalyticsTimer();
    await _server?.close(force: true);
    _server = null;
    _isBroadcasting = false;
    _selectedFiles.clear();
    _selectedFileNames.clear();
    _selectedFileSizes.clear();
    _connectedPeers.clear();
    _downloadCount = 0;
    notifyListeners();
  }

  // ──────────────────────────────────────────
  // RECEIVER: Access Request Server
  // ──────────────────────────────────────────

  Future<void> startReceiverServer(
      Future<bool> Function(String senderIp, String senderName, String baseUrl) onTransferRequest) async {
    _localIp ??= await _getLocalIp();
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler((request) => _handleReceiverServerRequest(request, onTransferRequest));

    try {
      _receiverServer = await shelf_io.serve(handler, '0.0.0.0', 0);
      _receiverPort = _receiverServer!.port;
    } catch (e) {
      debugPrint('Receiver server start error: \$e');
    }
  }

  Future<shelf.Response> _handleReceiverServerRequest(
      shelf.Request request,
      Future<bool> Function(String senderIp, String senderName, String baseUrl) onTransferRequest) async {
    if (request.url.path == 'request_transfer' && request.method == 'POST') {
      try {
        final payload = await request.readAsString();
        final data = jsonDecode(payload);
        final String senderIp = data['senderIp'] ?? 'Unknown IP';
        final String senderName = data['deviceName'] ?? 'Unknown Device';
        final String baseUrl = data['senderBaseUrl'] ?? '';

        // Trigger UI Callback
        final accepted = await onTransferRequest(senderIp, senderName, baseUrl);
        if (accepted) {
          downloadFile(baseUrl);
          return shelf.Response.ok(jsonEncode({'status': 'accepted'}), headers: {'Content-Type': 'application/json'});
        } else {
          return shelf.Response.forbidden(jsonEncode({'status': 'denied'}));
        }
      } catch (e) {
        return shelf.Response.internalServerError();
      }
    }
    return shelf.Response.notFound('Not found');
  }

  void stopReceiverServer() {
    _receiverServer?.close(force: true);
    _receiverServer = null;
    _receiverPort = 0;
  }

  // ──────────────────────────────────────────
  // RECEIVER: Multi-file Download
  // ──────────────────────────────────────────

  /// Downloads files from the given base URL.
  /// Supports both multi-file (/info + /download/<i>) and legacy single-file (/download).
  Future<void> downloadFile(String url) async {
    _isDownloading = true;
    _downloadProgress = 0.0;
    _currentFileProgress = 0.0;
    _downloadComplete = false;
    _downloadError = null;
    _downloadedFilePath = null;
    _downloadFileName = null;
    _totalFilesToReceive = 0;
    _currentFileIndex = 0;
    _receivedFiles.clear();
    notifyListeners();

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 30),
      ));

      // Determine base URL
      final baseUrl = url.replaceAll('/download', '').replaceAll(RegExp(r'/$'), '');

      // Try multi-file info endpoint first
      List<Map<String, dynamic>> fileList = [];
      try {
        final infoResponse = await dio.get('$baseUrl/info');
        if (infoResponse.statusCode == 200) {
          final data = infoResponse.data;
          if (data is Map && data.containsKey('files')) {
            fileList = List<Map<String, dynamic>>.from(data['files']);
          } else if (data is Map && data.containsKey('name')) {
            // Legacy single-file info
            fileList = [
              {'index': 0, 'name': data['name'], 'size': data['size']}
            ];
          }
        }
      } catch (_) {
        // Fallback: single file from legacy URL
        fileList = [
          {'index': 0, 'name': 'received_file', 'size': 0}
        ];
      }

      _totalFilesToReceive = fileList.length;
      notifyListeners();

      final totalSize = fileList.fold<int>(0, (sum, f) => sum + ((f['size'] as int?) ?? 0));
      int downloadedSoFar = 0;
      
      _startAnalyticsTimer(totalSize);

      // Download each file sequentially
      for (int i = 0; i < fileList.length; i++) {
        _currentFileIndex = i;
        _currentFileProgress = 0.0;
        final fileName = fileList[i]['name'] as String? ?? 'file_$i';
        final fileSize = (fileList[i]['size'] as int?) ?? 0;
        _downloadFileName = fileName;
        notifyListeners();

        // Determine download URL
        final downloadUrl = fileList.length > 1 || fileList[0].containsKey('index')
            ? '$baseUrl/download/$i'
            : '$baseUrl/download';

        // Build save path
        String savePath = '';
        if (Platform.isAndroid) {
          final dir = Directory('/storage/emulated/0/Download/ZeroWire');
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          savePath = '${dir.path}/$fileName';
        } else {
          final dir = await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
          savePath = '${dir.path}/$fileName';
        }

        // Handle duplicate filenames
        savePath = await _getUniquePath(savePath);

        // Throttle UI updates to ~30fps
        DateTime lastNotify = DateTime.now();

        await dio.download(
          downloadUrl,
          savePath,
          onReceiveProgress: (received, total) {
            _totalBytesTransferred = downloadedSoFar + received;
            if (total > 0) {
              _currentFileProgress = received / total;
            }
            // Calculate overall progress
            if (totalSize > 0) {
              _downloadProgress = _totalBytesTransferred / totalSize;
            } else {
              _downloadProgress = (i + _currentFileProgress) / fileList.length;
            }

            final now = DateTime.now();
            if (now.difference(lastNotify).inMilliseconds > 250 ||
                (total > 0 && received == total)) {
              lastNotify = now;
              notifyListeners();
            }
          },
        );

        downloadedSoFar += fileSize;
        _receivedFiles.add(savePath);

        // Scan media so it shows up in gallery/file managers
        if (Platform.isAndroid) {
          try {
            await MediaScanner.loadMedia(path: savePath);
          } catch (_) {}
        }

        // Add each file to history
        _history.insert(
          0,
          TransferRecord(
            fileName: fileName,
            fileSize: File(savePath).lengthSync(),
            timestamp: DateTime.now(),
            type: TransferType.received,
            filePath: savePath,
          ),
        );
      }

      _downloadedFilePath = _receivedFiles.isNotEmpty ? _receivedFiles.last : null;
      _downloadComplete = true;
      _isDownloading = false;
      _downloadProgress = 1.0;
      _stopAnalyticsTimer();
      notifyListeners();
    } catch (e) {
      _stopAnalyticsTimer();
      _downloadError = e.toString();
      _isDownloading = false;
      _downloadComplete = false;
      notifyListeners();
    }
  }

  /// Generates a unique file path to avoid overwriting existing files.
  Future<String> _getUniquePath(String path) async {
    if (!await File(path).exists()) return path;

    final dir = path.substring(0, path.lastIndexOf(Platform.pathSeparator));
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');

    String baseName;
    String extension;
    if (dotIndex > 0) {
      baseName = fileName.substring(0, dotIndex);
      extension = fileName.substring(dotIndex);
    } else {
      baseName = fileName;
      extension = '';
    }

    int counter = 1;
    String newPath;
    do {
      newPath = '$dir${Platform.pathSeparator}${baseName}_($counter)$extension';
      counter++;
    } while (await File(newPath).exists());

    return newPath;
  }

  /// Adds sent records to history for all selected files.
  void addSentRecord() {
    for (int i = 0; i < _selectedFileNames.length; i++) {
      _history.insert(
        0,
        TransferRecord(
          fileName: _selectedFileNames[i],
          fileSize: _selectedFileSizes[i],
          timestamp: DateTime.now(),
          type: TransferType.sent,
        ),
      );
    }
    notifyListeners();
  }

  /// Resets receiver state.
  void resetReceiver() {
    _isDownloading = false;
    _downloadProgress = 0.0;
    _currentFileProgress = 0.0;
    _downloadComplete = false;
    _downloadedFilePath = null;
    _downloadFileName = null;
    _downloadError = null;
    _totalFilesToReceive = 0;
    _currentFileIndex = 0;
    _receivedFiles.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopServer();
    super.dispose();
  }
}

enum TransferType { sent, received }

class TransferRecord {
  final String fileName;
  final int fileSize;
  final DateTime timestamp;
  final TransferType type;
  final String? filePath;

  TransferRecord({
    required this.fileName,
    required this.fileSize,
    required this.timestamp,
    required this.type,
    this.filePath,
  });

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
