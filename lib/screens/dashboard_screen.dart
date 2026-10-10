import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import 'tabs/gallery_tab.dart';
import 'tabs/apps_tab.dart';
import 'tabs/music_tab.dart';
import 'tabs/internal_storage_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  /// Shows the dashboard and returns selected files, or null if cancelled.
  static Future<List<File>?> pickFiles(BuildContext context) {
    return Navigator.of(context).push<List<File>>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const DashboardScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final Set<String> _selectedFiles = {};
  late TabController _tabController;
  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScale = CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedFiles.contains(path)) {
        _selectedFiles.remove(path);
      } else {
        _selectedFiles.add(path);
      }
    });

    if (_selectedFiles.isNotEmpty) {
      _fabController.forward();
    } else {
      _fabController.reverse();
    }
  }

  void _confirmSelection() {
    final files = _selectedFiles.map((p) => File(p)).toList();
    Navigator.of(context).pop(files);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background glows
          if (isDark) ...[
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ZWColors.neonCyan.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      ZWColors.neonPurple.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Main content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(null),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accent.withValues(alpha: 0.15)),
                          ),
                          child: Icon(LucideIcons.x, color: accent, size: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dashboard',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              _selectedFiles.isEmpty
                                  ? 'Select files to transmit'
                                  : '${_selectedFiles.length} item${_selectedFiles.length > 1 ? 's' : ''} selected',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Tabs ──
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(color: accent.withValues(alpha: 0.3), width: 1.5),
                  ),
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  labelColor: accent,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  labelStyle: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w500),
                  labelPadding: EdgeInsets.zero,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  dividerHeight: 0,
                  tabs: const [
                    Tab(text: "Gallery", icon: Icon(LucideIcons.image, size: 18)),
                    Tab(text: "Apps", icon: Icon(LucideIcons.layoutGrid, size: 18)),
                    Tab(text: "Music", icon: Icon(LucideIcons.music, size: 18)),
                    Tab(text: "Files", icon: Icon(LucideIcons.folder, size: 18)),
                  ],
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),

                // ── Tab Views ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      GalleryTab(selectedFiles: _selectedFiles, onToggle: _toggleSelect),
                      AppsTab(selectedFiles: _selectedFiles, onToggle: _toggleSelect),
                      MusicTab(selectedFiles: _selectedFiles, onToggle: _toggleSelect),
                      InternalStorageTab(selectedFiles: _selectedFiles, onToggle: _toggleSelect),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Floating Action Button ──
          Positioned(
            bottom: 32,
            right: 24,
            child: ScaleTransition(
              scale: _fabScale,
              child: GestureDetector(
                onTap: _selectedFiles.isNotEmpty ? _confirmSelection : null,
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.4 : 0.25),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.send,
                        color: isDark ? ZWColors.darkBackground : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'TRANSMIT ${_selectedFiles.length}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? ZWColors.darkBackground : Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
