import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../services/transfer_service.dart';
import '../widgets/glass_card.dart';
import 'sender_screen.dart';
import 'receiver_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPrivacyPolicy();
    });
  }

  Future<void> _checkPrivacyPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAgreed = prefs.getBool('privacy_policy_agreed') ?? false;

    if (!hasAgreed && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Data Privacy Disclosure',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: RichText(
            text: TextSpan(
              style: GoogleFonts.manrope(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'ZeroWire transmits your '),
                TextSpan(
                  text: 'Installed Application information',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const TextSpan(text: ' to enable the '),
                TextSpan(
                  text: 'sharing of your installed apps as APK files',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const TextSpan(
                  text: ', during local peer-to-peer transfers with nearby devices.\n\n',
                ),
                const TextSpan(
                  text: 'By clicking "I Agree", you consent to this data being accessed and transmitted to your paired devices.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Required to offer a decline, but the app needs the permission to function fully.
                // We'll let them decline, but they'll be prompted again next time.
                Navigator.of(context).pop();
              },
              child: const Text('Decline'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ZWColors.neonCyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                await prefs.setBool('privacy_policy_agreed', true);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('I Agree'),
            ),
          ],
        ),
      );
    }
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _HomeBody(onNavigate: _switchTab),
          const SenderScreen(),
          const ReceiverScreen(),
          const HistoryScreen(),
          const SettingsScreen(),
        ].asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          final isActive = index == _currentIndex;

          double dx = 0.0;
          if (index < _currentIndex) dx = -0.05;
          if (index > _currentIndex) dx = 0.05;

          return IgnorePointer(
            ignoring: !isActive,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              offset: Offset(isActive ? 0.0 : dx, 0.0),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                scale: isActive ? 1.0 : 0.96,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  opacity: isActive ? 1.0 : 0.0,
                  child: child,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;
    final inactive = isDark ? ZWColors.darkOutline : ZWColors.lightOutline;
    final bgColor = isDark
        ? Colors.black.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    final items = [
      _NavItem(icon: LucideIcons.layoutGrid, label: 'HOME'),
      _NavItem(icon: LucideIcons.upload, label: 'SEND'),
      _NavItem(icon: LucideIcons.scanLine, label: 'RECEIVE'),
      _NavItem(icon: LucideIcons.clock, label: 'HISTORY'),
      _NavItem(icon: LucideIcons.settings, label: 'SETTINGS'),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isSelected = i == _currentIndex;

                  return Flexible(
                    child: GestureDetector(
                      onTap: () => _switchTab(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 12 : 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? accent.withValues(alpha: 0.2)
                                : Colors.transparent,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected && isDark
                                  ? accent.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              blurRadius: 15,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected ? accent : inactive,
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                style: GoogleFonts.manrope(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: isSelected ? accent : inactive,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ──────────────────────────────────────────────
// Home Body (The Quantum Bridge screen)
// ──────────────────────────────────────────────

class _HomeBody extends StatelessWidget {
  final void Function(int) onNavigate;
  const _HomeBody({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final transfer = context.watch<TransferService>();

    return Stack(
      children: [
        // Background glow orbs
        if (isDark) ...[
          Positioned(
            top: -80,
            right: -120,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ZWColors.neonCyan.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -120,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ZWColors.neonPurple.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],

        // Main content
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // App bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ZeroWire', style: theme.appBarTheme.titleTextStyle),
                    StatusPulse(
                      label: 'Home',
                      color: isDark ? ZWColors.neonCyan : ZWColors.primaryDark,
                    ),
                  ],
                ),

                // Spacer to push content toward center
                const Spacer(flex: 2),

                // Status badge
                const StatusPulse(label: 'Node Online'),
                const SizedBox(height: 16),

                // Hero heading
                Text(
                  'Quantum Bridge',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ultra-fast peer-to-peer data transfer\nacross encrypted local channels.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Send card
                NeonActionCard(
                  onTap: () => onNavigate(1),
                  icon: LucideIcons.upload,
                  title: 'INITIALIZE NODE',
                  subtitle: '(SEND FILE)',
                  isCyan: true,
                ),

                const SizedBox(height: 16),

                // Receive card
                NeonActionCard(
                  onTap: () => onNavigate(2),
                  icon: LucideIcons.radio,
                  title: 'ESTABLISH LINK',
                  subtitle: '(RECEIVE)',
                  isCyan: false,
                ),

                const Spacer(flex: 1),

                // Recent transfer info
                if (transfer.history.isNotEmpty) ...[
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    borderRadius: BorderRadius.circular(100),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: Icon(
                            transfer.history.first.type == TransferType.sent
                                ? LucideIcons.arrowUpCircle
                                : LucideIcons.arrowDownCircle,
                            size: 20,
                            color: isDark ? ZWColors.neonCyan : ZWColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transfer.history.first.fileName,
                                style: theme.textTheme.labelLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${transfer.history.first.formattedSize} • ${transfer.history.first.formattedTime}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 100), // Space for bottom nav
              ],
            ),
          ),
        ),
      ],
    );
  }
}
