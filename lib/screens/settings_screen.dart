import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../widgets/glass_card.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ZeroWire', style: theme.appBarTheme.titleTextStyle),
                StatusPulse(label: 'Settings', color: ZWColors.neonCyan),
              ],
            ),
            const SizedBox(height: 32),

            Text(
              'GENERAL',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 16),

            // About card
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  _SettingsTile(
                    icon: LucideIcons.info,
                    title: 'About ZeroWire',
                    subtitle: 'Version 1.0.0',
                    onTap: () => _showAboutDialog(context, theme, isDark, accent),
                  ),
                  Divider(
                    color: theme.dividerColor,
                    height: 24,
                  ),
                  _SettingsTile(
                    icon: LucideIcons.shieldCheck,
                    title: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    onTap: () => _showPrivacyPolicy(context, theme, isDark, accent),
                  ),
                  Divider(
                    color: theme.dividerColor,
                    height: 24,
                  ),
                  _SettingsTile(
                    icon: LucideIcons.fileText,
                    title: 'Terms of Service',
                    subtitle: 'Usage guidelines',
                    onTap: () => _showTermsOfService(context, theme, isDark, accent),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'SYSTEM',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 16),

            GlassCard(
              padding: const EdgeInsets.all(20),
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: accent.withValues(alpha: 0.1),
                        ),
                        child: Icon(LucideIcons.moon, size: 20, color: accent),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Theme', style: theme.textTheme.titleSmall),
                            Text(
                              'Select app appearance',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedThemeSelector(
                    currentMode: themeProvider.themeMode,
                    onModeChanged: (mode) => themeProvider.setTheme(mode),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Footer
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  children: [
                    Text(
                      'ZeroWire',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: accent.withValues(alpha: 0.4),
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Peer-to-peer. Zero cloud. Zero traces.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context, ThemeData theme, bool isDark, Color accent) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'About',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: Colors.transparent,
              child: GlassCard(
                borderRadius: BorderRadius.circular(32),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.1),
                      ),
                      child: Icon(LucideIcons.terminal, size: 40, color: accent),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ZeroWire',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version 1.0.0',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ZeroWire is an ultra-fast, local peer-to-peer file transfer app. '
                      'Files are transferred directly between devices over your local Wi-Fi network. '
                      'No cloud servers, no accounts, no data collection.',
                      style: GoogleFonts.manrope(
                        height: 1.6,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: isDark ? ZWColors.darkBackground : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        child: Text(
                          'CLOSE',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, anim2, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
    );
  }

  void _showPrivacyPolicy(BuildContext context, ThemeData theme, bool isDark, Color accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? ZWColors.darkSurfaceContainer : ZWColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Privacy Policy',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    'ZeroWire Privacy Policy\n'
                    'Effective Date: April 2026\n\n'
                    'ZeroWire ("we," "our," or "the app") provides a high-speed, localized peer-to-peer (P2P) file transfer utility. '
                    'Because privacy and security are the core foundational pillars of ZeroWire, our data practices are incredibly simple: '
                    'We do not collect, transmit, store, or monitor any personal data, file content, or connection metadata to external servers.\n\n'
                    '1. How ZeroWire Operates (Local Subnet P2P)\n'
                    'ZeroWire is not a cloud-based application. When you select a file to transfer, the app temporarily spins up a closed HTTP node '
                    'localized strictly onto your current Wi-Fi network subnet. The generated QR Code contains local routing information that allows a peer '
                    'device on the same network to request the file directly from your device. Zero data is routed through third-party servers.\n\n'
                    '2. Permissions We Request & Why\n'
                    '• Camera Permission: Required entirely and exclusively for the "Receiver Node" to visually scan the local QR code broadcasted by the sender. '
                    'The camera stream is processed transiently on-device and is never uploaded.\n'
                    '• Installed Apps (QUERY_ALL_PACKAGES): To allow you to transfer your installed applications (APKs) to other devices, ZeroWire requires permission to query the list of user and system apps installed on your device. This data is only used locally to populate the "Apps" dashboard and is never collected, backed up, or shared with third parties.\n'
                    '• Media & Storage Permissions: Required to allow you to browse and select images, videos, music, and raw files (via the Dashboard) to securely transmit to your peers, and to save incoming files to your device storage.\n'
                    '• Network/Wi-Fi State: Required to determine your local IPv4 address ensuring the peer-to-peer socket can successfully bind locally.\n\n'
                    '3. Analytics and Third Parties\n'
                    'ZeroWire contains zero commercial tracking SDKs, advertising IDs (AdMob/Facebook), or crash-reporting analytics. You are entirely invisible to us.\n\n'
                    '4. Children\'s Privacy\n'
                    'Because the app has absolutely no tracking or cloud infrastructure, it inherently adheres to strict global children\'s privacy regulations (including COPPA).\n\n'
                    '5. Contact Us\n'
                    'If you have any questions about this Privacy Policy, please contact the developer via the associated Google Play Developer email address.',
                    style: GoogleFonts.manrope(
                      height: 1.7,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ), // closes Text
                ), // closes SingleChildScrollView
              ), // closes Expanded
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsOfService(BuildContext context, ThemeData theme, bool isDark, Color accent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? ZWColors.darkSurfaceContainer : ZWColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Terms of Service',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    'ZeroWire Terms of Service\n'
                    'Effective Date: April 2026\n\n'
                    'By using ZeroWire, you agree to these terms. ZeroWire is provided "as is" '
                    'for localized peer-to-peer file transfers.\n\n'
                    '1. Allowed Usage & Copyright\n'
                    'You agree to use this application exclusively for lawful purposes. You are solely responsible for the files, media, and applications (APKs) you choose to transmit to other devices. Do not transmit copyrighted material, intellectual property, or proprietary applications without the explicit consent of the rightsholder.\n\n'
                    '2. Local Network Limitations\n'
                    'Because connections are established exclusively over your local Wi-Fi subnet, we do not '
                    'guarantee connectivity on highly restricted corporate, university, or public networks '
                    'where peer-to-peer routing is blocked.\n\n'
                    '3. Disclaimer of Liability\n'
                    'We assume absolutely no liability for data loss, corrupted transfers, device damage, or malicious files '
                    'received over the ZeroWire protocol. Please verify the integrity of the sender and the QR Code source before initiating a download.\n\n'
                    '4. Privacy Guarantee\n'
                    'As explicitly documented in our Privacy Policy, this application has no cloud functionality. '
                    'We cannot retrieve your files, nor can we help you if you lose them.',
                    style: GoogleFonts.manrope(
                      height: 1.7,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accent.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

class AnimatedThemeSelector extends StatelessWidget {
  final ThemeMode currentMode;
  final Function(ThemeMode) onModeChanged;

  const AnimatedThemeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;
    
    final modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    final labels = ['System', 'Light', 'Dark'];
    final icons = [LucideIcons.settings, LucideIcons.sun, LucideIcons.moon];
    final selectedIndex = modes.indexOf(currentMode);

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment(
              selectedIndex == 0 ? -1.0 : (selectedIndex == 1 ? 0.0 : 1.0),
              0.0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              child: Container(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(3, (index) {
              final isSelected = index == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onModeChanged(modes[index]),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? accent : theme.colorScheme.onSurfaceVariant,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[index],
                            size: 14,
                            color: isSelected ? accent : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(labels[index]),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
