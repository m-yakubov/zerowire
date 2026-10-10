
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/theme.dart';
import '../services/transfer_service.dart';
import '../services/discovery_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/analytics_speed_chart.dart';
import 'dashboard_screen.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _radarSweepController;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _radarSweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final transfer = context.watch<TransferService>();
    if (transfer.isBroadcasting && !_radarController.isAnimating) {
      _radarController.repeat();
      _radarSweepController.repeat();
    } else if (!transfer.isBroadcasting && _radarController.isAnimating) {
      _radarController.stop();
      _radarSweepController.stop();
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _radarSweepController.dispose();
    super.dispose();
  }

  Future<void> _requestTransfer(DiscoveredDevice device, TransferService transfer) async {
    if (!transfer.isBroadcasting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select files to transmit first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final dio = Dio();
    final discovery = Provider.of<DiscoveryService>(context, listen: false);

    try {
      final response = await dio.post(
        'http://${device.ip}:${device.port}/request_transfer',
        data: {
          'deviceName': discovery.deviceName,
          'senderIp': discovery.ipAddress,
          'senderBaseUrl': transfer.connectionString,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 'accepted') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transfer accepted by device!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The requested device rejected the transfer'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('The requested device rejected the transfer'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to request transfer: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting transfer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _selectAndServe() async {
    final transfer = context.read<TransferService>();
    final discovery = context.read<DiscoveryService>();

    // Open our custom file explorer
    final files = await DashboardScreen.pickFiles(context);
    if (files == null || files.isEmpty) return;

    setState(() => _isStarting = true);

    try {
      final success = await transfer.startServer(files);

      if (success) {
        // Start listening for receiver broadcasts
        discovery.startListening();
      }

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to start server. Make sure you are connected to Wi-Fi.',
              style: GoogleFonts.manrope(),
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _stopBroadcasting() {
    final transfer = context.read<TransferService>();
    final discovery = context.read<DiscoveryService>();
    transfer.addSentRecord();
    transfer.stopServer();
    discovery.stopListening();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final transfer = context.watch<TransferService>();
    final discovery = context.watch<DiscoveryService>();
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    return Stack(
      children: [
        // Background glow
        if (isDark)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ZWColors.neonCyan.withValues(alpha: transfer.isBroadcasting ? 0.12 : 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Content
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
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
                          label: transfer.isBroadcasting ? 'Broadcasting' : 'Send',
                          color: transfer.isBroadcasting ? ZWColors.neonCyan : accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Scrollable Flexible Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                // QR Code area
                if (transfer.isBroadcasting) ...[
                  // QR Container with glow and Fixed Radar
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -150, bottom: -150, left: -150, right: -150,
                        child: AnimatedBuilder(
                          animation: _radarController,
                          builder: (context, child) => CustomPaint(
                            painter: _RadarPainter(
                              progress: _radarController.value,
                              color: accent,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: isDark
                              ? [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.2),
                                    blurRadius: 60,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.1),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                        ),
                        child: GlassCard(
                          borderRadius: BorderRadius.circular(32),
                          borderColor: accent.withValues(alpha: 0.2),
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: QrImageView(
                              data: '${transfer.connectionString}/download',
                              version: QrVersions.auto,
                              size: 200,
                              eyeStyle: QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: isDark ? ZWColors.primaryDark : Colors.black,
                              ),
                              dataModuleStyle: QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: isDark ? ZWColors.primaryDark : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Broadcasting chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                      boxShadow: isDark
                          ? [BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 20)]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent,
                            boxShadow: isDark
                                ? [BoxShadow(color: accent, blurRadius: 8)]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'BROADCASTING · ${transfer.selectedFileCount} FILE${transfer.selectedFileCount > 1 ? 'S' : ''}',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    borderRadius: BorderRadius.circular(32),
                    child: AnalyticsSpeedChart(
                      currentSpeedMBps: transfer.currentSpeedMBps,
                      eta: transfer.eta,
                      speedHistory: transfer.speedHistory,
                      accentColor: accent,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Connected Peers ──
                  if (transfer.connectedPeers.isNotEmpty) ...[
                    Text(
                      'CONNECTED PEERS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: accent.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: transfer.connectedPeers.map((ip) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            border: Border.all(color: accent.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.smartphone, size: 14, color: accent),
                              const SizedBox(width: 8),
                              Text(ip, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Device Radar ──
                  if (discovery.devices.isNotEmpty)
                    _DeviceRadarList(
                      devices: discovery.devices,
                      accent: accent,
                      isDark: isDark,
                      onDeviceTap: (device) => _requestTransfer(device, transfer),
                    ),
                ] else ...[
                  // Empty state placeholder
                  GlassCard(
                    borderRadius: BorderRadius.circular(32),
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.cloud,
                          size: 64,
                          color: accent.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Payload Selected',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select files below to start broadcasting',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // File info card
                GlassCard(
                  borderRadius: BorderRadius.circular(24),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                            child: Icon(
                              transfer.isBroadcasting
                                  ? (transfer.selectedFileCount > 1
                                      ? LucideIcons.files
                                      : LucideIcons.cloud)
                                  : LucideIcons.cloud,
                              color: accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transfer.isBroadcasting
                                      ? (transfer.selectedFileCount > 1
                                          ? '${transfer.selectedFileCount} Files Queued'
                                          : transfer.selectedFileName ?? 'Unknown')
                                      : 'Awaiting Payload...',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  transfer.isBroadcasting
                                      ? 'Connection: Secure P2P'
                                      : 'No files selected',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              theme.dividerColor,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _InfoColumn(
                            label: 'SIZE',
                            value: transfer.isBroadcasting
                                ? _formatSize(transfer.totalSelectedSize)
                                : '---',
                            theme: theme,
                          ),
                          _InfoColumn(
                            label: 'FILES',
                            value: transfer.isBroadcasting
                                ? '${transfer.selectedFileCount}'
                                : '---',
                            theme: theme,
                          ),
                          _InfoColumn(
                            label: 'DOWNLOADS',
                            value: transfer.isBroadcasting
                                ? '${transfer.downloadCount}'
                                : '---',
                            theme: theme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
          
          // Action button synchronously at the bottom of the screen (inside the SafeArea Column)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16).copyWith(bottom: 100), // Clears global navbar
            width: double.infinity,
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _isStarting
                    ? null
                    : transfer.isBroadcasting
                        ? _stopBroadcasting
                        : _selectAndServe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: transfer.isBroadcasting
                      ? Colors.red.shade700
                      : accent,
                  foregroundColor: transfer.isBroadcasting
                      ? Colors.white
                      : (isDark ? ZWColors.darkBackground : Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 8,
                  shadowColor: transfer.isBroadcasting 
                      ? Colors.red.shade700.withValues(alpha: 0.4) 
                      : accent.withValues(alpha: 0.4),
                ),
                child: _isStarting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: isDark ? ZWColors.darkBackground : Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            transfer.isBroadcasting
                                ? LucideIcons.xSquare
                                : LucideIcons.plusSquare,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            transfer.isBroadcasting
                                ? 'STOP BROADCAST'
                                : 'SELECT PAYLOAD TO TRANSMIT',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  ],
);
}

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// ──────────────────────────────────────────────
// Discovered Device Radar List
// ──────────────────────────────────────────────

class _DeviceRadarList extends StatelessWidget {
  final List<DiscoveredDevice> devices;
  final Color accent;
  final bool isDark;
  final void Function(DiscoveredDevice)? onDeviceTap;

  const _DeviceRadarList({
    required this.devices,
    required this.accent,
    required this.isDark,
    this.onDeviceTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section label
        Row(
          children: [
            Icon(LucideIcons.radio, size: 14, color: accent.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              'DEVICES DETECTED',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: accent.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            Text(
              '${devices.length}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Device list
        ...devices.map((device) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onDeviceTap?.call(device),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? ZWColors.darkSurfaceContainer.withValues(alpha: 0.5)
                          : ZWColors.lightSurfaceContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(LucideIcons.smartphone, color: accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          device.ip,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ZWColors.neonGreen,
                      boxShadow: isDark
                          ? [BoxShadow(color: ZWColors.neonGreen, blurRadius: 6)]
                          : null,
                    ),
                  ),
                ],
              ),
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Info Column
// ──────────────────────────────────────────────

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;

  const _InfoColumn({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Radar ring painter for the broadcasting effect
// ──────────────────────────────────────────────

class _RadarPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  _RadarPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 4; i++) {
      final ringProgress = (progress + i * 0.25) % 1.0;
      final radius = maxRadius * ringProgress;
      
      // Calculate original opacity curve
      double opacity = (1.0 - ringProgress) * (isDark ? 0.25 : 0.15); // slightly increased visibility

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.progress != progress;
}
