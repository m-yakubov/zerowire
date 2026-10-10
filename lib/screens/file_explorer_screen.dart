import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';

// ──────────────────────────────────────────────
// ZeroWire File Explorer — Premium File Browser
// ──────────────────────────────────────────────

/// A beautifully designed, full-screen local file explorer.
/// Supports multi-select and returns a list of selected [File] objects.
class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  /// Shows the file explorer and returns selected files, or null if cancelled.
  static Future<List<File>?> pickFiles(BuildContext context) {
    return Navigator.of(context).push<List<File>>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const FileExplorerScreen(),
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
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen>
    with SingleTickerProviderStateMixin {
  Directory _currentDir = Directory('/storage/emulated/0');
  List<FileSystemEntity> _entries = [];
  final Set<String> _selected = {};
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _error;
  _SortMode _sortMode = _SortMode.name;
  bool _showHidden = false;

  late AnimationController _fabController;
  late Animation<double> _fabScale;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScale = CurvedAnimation(parent: _fabController, curve: Curves.easeOutBack);
    _checkPermissions();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) {
        _hasPermission = true;
        _loadDirectory(_currentDir);
      } else {
        final result = await Permission.manageExternalStorage.request();
        if (result.isGranted) {
          _hasPermission = true;
          _loadDirectory(_currentDir);
        } else {
          setState(() {
            _hasPermission = false;
            _isLoading = false;
            _error = 'Storage permission required to browse files.';
          });
        }
      }
    } else {
      _hasPermission = true;
      _loadDirectory(_currentDir);
    }
  }

  Future<void> _loadDirectory(Directory dir) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = <FileSystemEntity>[];
      await for (final entity in dir.list(followLinks: false)) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (!_showHidden && name.startsWith('.')) continue;
        entries.add(entity);
      }

      // Sort
      entries.sort((a, b) {
        // Directories first
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;

        final aName = a.path.split(Platform.pathSeparator).last.toLowerCase();
        final bName = b.path.split(Platform.pathSeparator).last.toLowerCase();

        switch (_sortMode) {
          case _SortMode.name:
            return aName.compareTo(bName);
          case _SortMode.size:
            if (a is File && b is File) {
              return b.lengthSync().compareTo(a.lengthSync());
            }
            return aName.compareTo(bName);
          case _SortMode.date:
            try {
              return b.statSync().modified.compareTo(a.statSync().modified);
            } catch (_) {
              return 0;
            }
        }
      });

      setState(() {
        _currentDir = dir;
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Cannot access this directory';
        _isLoading = false;
      });
    }
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
    if (_selected.isNotEmpty) {
      _fabController.forward();
    } else {
      _fabController.reverse();
    }
  }

  void _navigateTo(Directory dir) {
    _loadDirectory(dir);
  }

  void _goUp() {
    final parent = _currentDir.parent;
    if (parent.path != _currentDir.path) {
      _loadDirectory(parent);
    }
  }

  void _confirmSelection() {
    final files = _selected.map((p) => File(p)).toList();
    Navigator.of(context).pop(files);
  }

  // ── Breadcrumb path segments ──
  List<_BreadcrumbItem> _buildBreadcrumbs() {
    final basePath = '/storage/emulated/0';
    final currentPath = _currentDir.path;

    if (!currentPath.startsWith(basePath)) {
      return [_BreadcrumbItem('Storage', _currentDir)];
    }

    final items = <_BreadcrumbItem>[
      _BreadcrumbItem('Storage', Directory(basePath)),
    ];

    final relative = currentPath.substring(basePath.length);
    if (relative.isNotEmpty) {
      final parts = relative.split(Platform.pathSeparator).where((p) => p.isNotEmpty);
      String accumulated = basePath;
      for (final part in parts) {
        accumulated += '${Platform.pathSeparator}$part';
        items.add(_BreadcrumbItem(part, Directory(accumulated)));
      }
    }

    return items;
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
                              'File Explorer',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              _selected.isEmpty
                                  ? 'Select files to transmit'
                                  : '${_selected.length} file${_selected.length > 1 ? 's' : ''} selected',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Sort button
                      GestureDetector(
                        onTap: _showSortOptions,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accent.withValues(alpha: 0.15)),
                          ),
                          child: Icon(LucideIcons.arrowUpDown, color: accent, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Breadcrumb navigation ──
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Home / Go up button
                      GestureDetector(
                        onTap: _goUp,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(LucideIcons.chevronLeft, size: 16, color: accent),
                        ),
                      ),
                      ..._buildBreadcrumbs().map((crumb) {
                        final isLast = crumb.dir.path == _currentDir.path;
                        return GestureDetector(
                          onTap: isLast ? null : () => _navigateTo(crumb.dir),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: isLast
                                  ? accent.withValues(alpha: 0.15)
                                  : accent.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: isLast
                                  ? Border.all(color: accent.withValues(alpha: 0.3))
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  crumb.label,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: isLast ? FontWeight.w700 : FontWeight.w500,
                                    color: isLast
                                        ? accent
                                        : theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (!isLast) ...[
                                  const SizedBox(width: 4),
                                  Icon(LucideIcons.chevronRight,
                                      size: 12,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.5)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ── File List ──
                Expanded(
                  child: _buildBody(theme, isDark, accent),
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
                onTap: _selected.isNotEmpty ? _confirmSelection : null,
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
                        'TRANSMIT ${_selected.length}',
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

  Widget _buildBody(ThemeData theme, bool isDark, Color accent) {
    if (!_hasPermission) {
      return _buildEmptyState(
        theme,
        accent,
        LucideIcons.shieldOff,
        'Permission Required',
        _error ?? 'Storage access is needed to browse files.',
        actionLabel: 'GRANT ACCESS',
        onAction: _checkPermissions,
      );
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: accent, strokeWidth: 2.5),
      );
    }

    if (_error != null) {
      return _buildEmptyState(
        theme,
        accent,
        LucideIcons.folderX,
        'Access Denied',
        _error!,
        actionLabel: 'GO BACK',
        onAction: _goUp,
      );
    }

    if (_entries.isEmpty) {
      return _buildEmptyState(
        theme,
        accent,
        LucideIcons.folderOpen,
        'Empty Folder',
        'This directory contains no files.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entity = _entries[index];
        return _FileListTile(
          entity: entity,
          isSelected: _selected.contains(entity.path),
          onTap: () {
            if (entity is Directory) {
              _navigateTo(entity);
            } else {
              _toggleSelect(entity.path);
            }
          },
          onLongPress: entity is File ? () => _toggleSelect(entity.path) : null,
          accent: accent,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    Color accent,
    IconData icon,
    String title,
    String subtitle, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: accent.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSortOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? ZWColors.darkSurface : ZWColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SORT BY',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                  color: accent,
                ),
              ),
              const SizedBox(height: 16),
              _SortOption(
                icon: LucideIcons.arrowDownAZ,
                label: 'Name',
                isActive: _sortMode == _SortMode.name,
                accent: accent,
                onTap: () {
                  setState(() => _sortMode = _SortMode.name);
                  _loadDirectory(_currentDir);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                icon: LucideIcons.arrowDown01,
                label: 'Size',
                isActive: _sortMode == _SortMode.size,
                accent: accent,
                onTap: () {
                  setState(() => _sortMode = _SortMode.size);
                  _loadDirectory(_currentDir);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                icon: LucideIcons.calendarDays,
                label: 'Date Modified',
                isActive: _sortMode == _SortMode.date,
                accent: accent,
                onTap: () {
                  setState(() => _sortMode = _SortMode.date);
                  _loadDirectory(_currentDir);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _SortOption(
                icon: _showHidden ? LucideIcons.eye : LucideIcons.eyeOff,
                label: _showHidden ? 'Hide Hidden Files' : 'Show Hidden Files',
                isActive: _showHidden,
                accent: accent,
                onTap: () {
                  setState(() => _showHidden = !_showHidden);
                  _loadDirectory(_currentDir);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// File List Tile
// ──────────────────────────────────────────────

class _FileListTile extends StatelessWidget {
  final FileSystemEntity entity;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color accent;
  final bool isDark;

  const _FileListTile({
    required this.entity,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = entity.path.split(Platform.pathSeparator).last;
    final isDir = entity is Directory;
    final ext = isDir ? '' : (name.contains('.') ? name.split('.').last.toLowerCase() : '');
    final iconInfo = _getFileIcon(ext, isDir);
    
    String sizeStr = '';
    if (!isDir) {
      try {
        sizeStr = _formatSize((entity as File).lengthSync());
      } catch (_) {
        sizeStr = '---';
      }
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : (isDark
                  ? ZWColors.darkSurfaceContainer.withValues(alpha: 0.4)
                  : ZWColors.lightSurfaceContainer.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            // File type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconInfo.color.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconInfo.icon, color: iconInfo.color, size: 22),
            ),
            const SizedBox(width: 14),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? accent : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isDir)
                    Text(
                      '${ext.toUpperCase()} • $sizeStr',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  if (isDir)
                    Text(
                      'Folder',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            // Selection indicator or chevron
            if (isDir)
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? accent : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? accent
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        LucideIcons.check,
                        size: 14,
                        color: isDark ? ZWColors.darkBackground : Colors.white,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  static _FileIconInfo _getFileIcon(String ext, bool isDir) {
    if (isDir) return _FileIconInfo(LucideIcons.folder, const Color(0xFFFFA726));

    switch (ext) {
      // Images
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'bmp':
      case 'svg':
        return _FileIconInfo(LucideIcons.image, const Color(0xFF66BB6A));
      // Videos
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case 'wmv':
      case 'flv':
      case 'webm':
        return _FileIconInfo(LucideIcons.film, const Color(0xFFEF5350));
      // Audio
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
      case 'wma':
      case 'm4a':
        return _FileIconInfo(LucideIcons.music, const Color(0xFFAB47BC));
      // Documents
      case 'pdf':
        return _FileIconInfo(LucideIcons.fileText, const Color(0xFFE53935));
      case 'doc':
      case 'docx':
        return _FileIconInfo(LucideIcons.fileText, const Color(0xFF1E88E5));
      case 'xls':
      case 'xlsx':
        return _FileIconInfo(LucideIcons.table, const Color(0xFF43A047));
      case 'ppt':
      case 'pptx':
        return _FileIconInfo(LucideIcons.presentation, const Color(0xFFE65100));
      case 'txt':
      case 'log':
      case 'md':
        return _FileIconInfo(LucideIcons.fileText, const Color(0xFF78909C));
      // Archives
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return _FileIconInfo(LucideIcons.archive, const Color(0xFF8D6E63));
      // Code
      case 'dart':
      case 'py':
      case 'js':
      case 'ts':
      case 'java':
      case 'kt':
      case 'swift':
      case 'c':
      case 'cpp':
      case 'h':
      case 'html':
      case 'css':
      case 'json':
      case 'xml':
      case 'yaml':
        return _FileIconInfo(LucideIcons.code2, const Color(0xFF26C6DA));
      // Android packages
      case 'apk':
      case 'aab':
      case 'xapk':
        return _FileIconInfo(LucideIcons.smartphone, const Color(0xFF66BB6A));
      // Fonts
      case 'ttf':
      case 'otf':
      case 'woff':
        return _FileIconInfo(LucideIcons.type, const Color(0xFF7E57C2));
      // Database
      case 'db':
      case 'sqlite':
      case 'sql':
        return _FileIconInfo(LucideIcons.database, const Color(0xFF5C6BC0));
      default:
        return _FileIconInfo(LucideIcons.file, const Color(0xFF90A4AE));
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _FileIconInfo {
  final IconData icon;
  final Color color;
  const _FileIconInfo(this.icon, this.color);
}

// ──────────────────────────────────────────────
// Sort Controls
// ──────────────────────────────────────────────

enum _SortMode { name, size, date }

class _SortOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;

  const _SortOption({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? accent : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? accent : theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (isActive)
              Icon(LucideIcons.check, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbItem {
  final String label;
  final Directory dir;
  const _BreadcrumbItem(this.label, this.dir);
}
