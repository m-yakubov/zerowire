import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

enum _AppFilter { allApps, systemApps, userApps }

class AppsTab extends StatefulWidget {
  final Set<String> selectedFiles;
  final Function(String path) onToggle;

  const AppsTab({
    super.key,
    required this.selectedFiles,
    required this.onToggle,
  });

  @override
  State<AppsTab> createState() => _AppsTabState();
}

class _AppsTabState extends State<AppsTab> with AutomaticKeepAliveClientMixin {
  List<Application> _allApps = [];
  List<Application> _filteredApps = [];
  bool _isLoading = true;
  _AppFilter _filter = _AppFilter.allApps;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: true,
      onlyAppsWithLaunchIntent: false,
    );

    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

    if (!mounted) return;
    setState(() => _allApps = apps);
    _applyFilter();
  }

  void _applyFilter() {
    List<Application> result;
    switch (_filter) {
      case _AppFilter.userApps:
        result = _allApps.where((a) => !a.systemApp).toList();
        break;
      case _AppFilter.systemApps:
        result = _allApps.where((a) => a.systemApp).toList();
        break;
      case _AppFilter.allApps:
        result = List.from(_allApps);
        break;
    }

    if (!mounted) return;
    setState(() {
      _filteredApps = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2.5));
    }

    return Column(
      children: [
        // ── Filter chips ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildChip('All', _filter == _AppFilter.allApps, accent, () {
                setState(() => _filter = _AppFilter.allApps);
                _applyFilter();
              }),
              const SizedBox(width: 8),
              _buildChip('System', _filter == _AppFilter.systemApps, accent, () {
                setState(() => _filter = _AppFilter.systemApps);
                _applyFilter();
              }),
              const SizedBox(width: 8),
              _buildChip('User', _filter == _AppFilter.userApps, accent, () {
                setState(() => _filter = _AppFilter.userApps);
                _applyFilter();
              }),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_filteredApps.length} apps',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, fontWeight: FontWeight.w700, color: accent,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── List ──
        Expanded(
          child: _filteredApps.isEmpty
              ? Center(child: Text('No applications found', style: GoogleFonts.manrope(
                  color: theme.colorScheme.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                  cacheExtent: 500,
                  itemCount: _filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = _filteredApps[index];
                    return RepaintBoundary(
                      child: _AppTile(
                        app: app,
                        isSelected: widget.selectedFiles.contains(app.apkFilePath),
                        onTap: () => widget.onToggle(app.apkFilePath),
                        accent: accent,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, bool selected, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accent : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? accent : Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ),
    );
  }
}

/// Extracted tile — no AnimatedContainer, uses plain Container for scroll performance.
class _AppTile extends StatelessWidget {
  final Application app;
  final bool isSelected;
  final VoidCallback onTap;
  final Color accent;
  final bool isDark;

  const _AppTile({
    required this.app,
    required this.isSelected,
    required this.onTap,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget iconWidget;
    if (app is ApplicationWithIcon) {
      iconWidget = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory((app as ApplicationWithIcon).icon, width: 42, height: 42, gaplessPlayback: true),
      );
    } else {
      iconWidget = Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.android, color: accent, size: 22),
      );
    }

    String sizeLabel = '';
    try {
      final file = File(app.apkFilePath);
      if (file.existsSync()) {
        sizeLabel = _formatSize(file.lengthSync());
      }
    } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : (isDark
                  ? ZWColors.darkSurfaceContainer.withValues(alpha: 0.4)
                  : ZWColors.lightSurfaceContainer.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent.withValues(alpha: 0.35) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? accent : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          app.versionName ?? '',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (sizeLabel.isNotEmpty)
                        Text(
                          '  •  $sizeLabel',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accent : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accent : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }
}
