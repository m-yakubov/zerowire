import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import '../config/theme.dart';
import '../services/transfer_service.dart';
import '../services/discovery_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/analytics_speed_chart.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );

  bool _scanned = false;
  late AnimationController _scanLineController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Start broadcasting presence so senders can discover us
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final discovery = context.read<DiscoveryService>();
      final transfer = context.read<TransferService>();
      discovery.setDeviceName(_getDeviceName());
      
      await transfer.startReceiverServer(_handleTransferRequest);
      discovery.startBroadcasting(serverPort: transfer.receiverPort);
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _scanLineController.dispose();
    _pulseController.dispose();

    // Stop discovery broadcasting
    try {
      context.read<DiscoveryService>().stopBroadcasting();
      context.read<TransferService>().stopReceiverServer();
    } catch (_) {}

    super.dispose();
  }

  String _getDeviceName() {
    try {
      if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
        return 'iPhone';
      }
    } catch (_) {}
    return 'ZeroWire Device';
  }

  Future<bool> _handleTransferRequest(String senderIp, String senderName, String baseUrl) async {
    final theme = Theme.of(context);
    final accent = theme.brightness == Brightness.dark ? ZWColors.neonCyan : ZWColors.primaryDark;

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Incoming Transfer', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: accent)),
        content: Text(
          'Do you accept receiving data from $senderName: $senderIp?',
           style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('DENY', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
               setState(() => _scanned = true); 
               Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent, 
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('ACCEPT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || _scanned) return;

    final rawValue = barcode.rawValue;
    if (rawValue == null || !rawValue.startsWith('http')) return;

    setState(() => _scanned = true);

    final transfer = context.read<TransferService>();
    transfer.downloadFile(rawValue);
  }

  void _resetScanner() {
    final transfer = context.read<TransferService>();
    transfer.resetReceiver();
    setState(() => _scanned = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final transfer = context.watch<TransferService>();
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    return Stack(
      children: [
        // Background
        if (isDark)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomCenter,
                  radius: 1.0,
                  colors: [
                    ZWColors.neonPurple.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ZeroWire', style: theme.appBarTheme.titleTextStyle),
                    StatusPulse(
                      label: _getStatusLabel(transfer),
                      color: _getStatusColor(transfer),
                    ),
                  ],
                ),

                const Spacer(flex: 2),

                // Scanner or transfer state
                if (!_scanned) ...[
                  _buildScannerView(theme, isDark, accent),
                ] else if (transfer.isDownloading) ...[
                  _buildDownloadingView(theme, isDark, accent, transfer),
                ] else if (transfer.downloadComplete) ...[
                  _buildCompleteView(theme, isDark, accent, transfer),
                ] else if (transfer.downloadError != null) ...[
                  _buildErrorView(theme, isDark, accent, transfer),
                ] else ...[
                  _buildConnectingView(theme, isDark, accent),
                ],

                const Spacer(flex: 1),

                // Bottom action
                Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: transfer.downloadComplete || transfer.downloadError != null
                      ? SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _resetScanner,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: isDark ? ZWColors.darkBackground : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.scan, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'SCAN AGAIN',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusLabel(TransferService transfer) {
    if (transfer.downloadComplete) return 'Complete';
    if (transfer.isDownloading) return 'Receiving';
    if (transfer.downloadError != null) return 'Failed';
    if (_scanned) return 'Connecting';
    return 'Receive';
  }

  Color _getStatusColor(TransferService transfer) {
    if (transfer.downloadComplete) return ZWColors.neonGreen;
    if (transfer.downloadError != null) return ZWColors.error;
    return ZWColors.neonCyan;
  }

  // ── Scanner View ──

  Widget _buildScannerView(ThemeData theme, bool isDark, Color accent) {
    return Column(
      children: [
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 40,
                      spreadRadius: 3,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                // Camera
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                // Scan overlay
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: accent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                // Scanning line
                AnimatedBuilder(
                  animation: _scanLineController,
                  builder: (context, child) => Positioned(
                    top: 8 + (_scanLineController.value * 260),
                    left: 8,
                    right: 8,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            accent,
                            accent,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: isDark
                            ? [BoxShadow(color: accent, blurRadius: 8)]
                            : null,
                      ),
                    ),
                  ),
                ),
                // Corner decorations
                ..._buildCornerBrackets(accent, isDark),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'SCANNING FOR SENDER',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: accent.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Point your camera at the sender\'s QR code',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCornerBrackets(Color accent, bool isDark) {
    const size = 24.0;
    const borderWidth = 3.0;
    final color = accent.withValues(alpha: isDark ? 0.8 : 0.6);

    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: borderWidth),
              left: BorderSide(color: color, width: borderWidth),
            ),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(32)),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: borderWidth),
              right: BorderSide(color: color, width: borderWidth),
            ),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(32)),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: borderWidth),
              left: BorderSide(color: color, width: borderWidth),
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32)),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: borderWidth),
              right: BorderSide(color: color, width: borderWidth),
            ),
            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(32)),
          ),
        ),
      ),
    ];
  }

  // ── Downloading View ──

  Widget _buildDownloadingView(
      ThemeData theme, bool isDark, Color accent, TransferService transfer) {
    final progress = (transfer.downloadProgress * 100).clamp(0, 100);

    return GlassCard(
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Animated progress ring
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: transfer.downloadProgress,
                    strokeWidth: 6,
                    backgroundColor: accent.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(accent),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${progress.toStringAsFixed(0)}%',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'RECEIVING DATA',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: accent,
            ),
          ),

          const SizedBox(height: 8),

          // Current file info
          if (transfer.downloadFileName != null)
            Text(
              transfer.downloadFileName!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

          // File counter
          if (transfer.totalFilesToReceive > 1) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'FILE ${transfer.currentFileIndex + 1} OF ${transfer.totalFilesToReceive}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: accent.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 32),
          
          // Analytics Speed Chart
          AnalyticsSpeedChart(
            currentSpeedMBps: transfer.currentSpeedMBps,
            eta: transfer.eta,
            speedHistory: transfer.speedHistory,
            accentColor: accent,
          ),
        ],
      ),
    );
  }

  // ── Complete View ──

  Widget _buildCompleteView(
      ThemeData theme, bool isDark, Color accent, TransferService transfer) {
    return GlassCard(
      borderRadius: BorderRadius.circular(32),
      borderColor: ZWColors.neonGreen.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZWColors.neonGreen.withValues(alpha: 0.15),
            ),
            child: Icon(
              LucideIcons.checkCircle2,
              size: 40,
              color: ZWColors.neonGreen,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'TRANSFER COMPLETE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: ZWColors.neonGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            transfer.receivedFiles.length > 1
                ? '${transfer.receivedFiles.length} files saved to Downloads/ZeroWire'
                : transfer.downloadFileName ?? 'File saved',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (transfer.receivedFiles.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Show received files
            ...transfer.receivedFiles.take(5).map((filePath) {
              final name = filePath.split(Platform.pathSeparator).last;
              return GestureDetector(
                onTap: () => OpenFilex.open(filePath),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? ZWColors.darkSurfaceContainer.withValues(alpha: 0.4)
                        : ZWColors.lightSurfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.fileCheck, size: 16, color: ZWColors.neonGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(LucideIcons.externalLink, size: 14, color: accent.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              );
            }),
            if (transfer.receivedFiles.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${transfer.receivedFiles.length - 5} more files',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Error View ──

  Widget _buildErrorView(
      ThemeData theme, bool isDark, Color accent, TransferService transfer) {
    return GlassCard(
      borderRadius: BorderRadius.circular(32),
      borderColor: ZWColors.error.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ZWColors.error.withValues(alpha: 0.15),
            ),
            child: const Icon(
              LucideIcons.xCircle,
              size: 40,
              color: ZWColors.error,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'TRANSFER FAILED',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: ZWColors.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure both devices are on the same network.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Connecting View ──

  Widget _buildConnectingView(ThemeData theme, bool isDark, Color accent) {
    return GlassCard(
      borderRadius: BorderRadius.circular(32),
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'CONNECTING TO SENDER',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
