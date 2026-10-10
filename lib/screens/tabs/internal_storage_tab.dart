import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../config/theme.dart';

enum _SortMode { name, size, date }

/// Holds pre-fetched metadata so sorting never touches disk on the UI thread.
class _EntryMeta {
  final FileSystemEntity entity;
  final String name;
  final bool isDir;
  final int size;        // 0 for directories
  final DateTime modified;

  _EntryMeta({
    required this.entity,
    required this.name,
    required this.isDir,
    required this.size,
    required this.modified,
  });
}

class _BreadcrumbItem {
  final String label;
  final Directory dir;
  _BreadcrumbItem(this.label, this.dir);
}

/// Top-level function for use with compute() — runs in an Isolate.
/// Returns a list of maps with path, name, isDir, size, modified.
Future<List<Map<String, dynamic>>> _listAndStatDirectory(Map<String, dynamic> args) async {
  final dirPath = args['path'] as String;
  final showHidden = args['showHidden'] as bool;

  final dir = Directory(dirPath);
  final results = <Map<String, dynamic>>[];

  try {
    await for (final entity in dir.list(followLinks: false)) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!showHidden && name.startsWith('.')) continue;

      // Gather metadata asynchronously
      try {
        final stat = await entity.stat();
        results.add({
          'path': entity.path,
          'name': name,
          'isDir': stat.type == FileSystemEntityType.directory,
          'size': stat.size,
          'modified': stat.modified.millisecondsSinceEpoch,
        });
      } catch (_) {
        // If we can't stat (permission denied, etc.), still include it
        results.add({
          'path': entity.path,
          'name': name,
          'isDir': entity is Directory,
          'size': 0,
          'modified': 0,
        });
      }
    }
  } catch (_) {
    // Directory listing failed entirely — return empty
  }

  return results;
}

class InternalStorageTab extends StatefulWidget {
  final Set<String> selectedFiles;
  final Function(String path) onToggle;

  const InternalStorageTab({
    super.key,
    required this.selectedFiles,
    required this.onToggle,
  });

  @override
  State<InternalStorageTab> createState() => _InternalStorageTabState();
}

class _InternalStorageTabState extends State<InternalStorageTab>
    with AutomaticKeepAliveClientMixin {
  Directory _currentDir = Directory('/storage/emulated/0');
  List<_EntryMeta> _entries = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _error;
  _SortMode _sortMode = _SortMode.name;
  bool _showHidden = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) {
        if (mounted) {
          setState(() => _hasPermission = true);
          _loadDirectory(_currentDir);
        }
      } else {
        final result = await Permission.manageExternalStorage.request();
        if (result.isGranted) {
          if (mounted) {
            setState(() => _hasPermission = true);
            _loadDirectory(_currentDir);
          }
        } else {
          if (mounted) {
            setState(() {
              _hasPermission = false;
              _isLoading = false;
              _error = 'Storage permission required to browse files.';
            });
          }
        }
      }
    } else {
      if (mounted) {
        setState(() => _hasPermission = true);
        _loadDirectory(_currentDir);
      }
    }
  }

  /// Fully async directory load — all metadata gathered off-thread via compute().
  Future<void> _loadDirectory(Directory dir) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Run directory listing + stat() in an isolate to prevent ANR
      final rawEntries = await compute(_listAndStatDirectory, {
        'path': dir.path,
        'showHidden': _showHidden,
      });

      // Convert raw maps back to _EntryMeta objects (on main thread, no I/O)
      final entries = rawEntries.map((m) => _EntryMeta(
        entity: (m['isDir'] as bool) ? Directory(m['path'] as String) : File(m['path'] as String),
        name: m['name'] as String,
        isDir: m['isDir'] as bool,
        size: m['size'] as int,
        modified: DateTime.fromMillisecondsSinceEpoch(m['modified'] as int),
      )).toList();

      // Sort using pre-fetched metadata — zero disk I/O
      entries.sort((a, b) {
        if (a.isDir && !b.isDir) return -1;
        if (!a.isDir && b.isDir) return 1;

        switch (_sortMode) {
          case _SortMode.name:
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case _SortMode.size:
            if (!a.isDir && !b.isDir) {
              return b.size.compareTo(a.size);
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case _SortMode.date:
            return b.modified.compareTo(a.modified);
        }
      });

      if (!mounted) return;
      setState(() {
        _currentDir = dir;
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Cannot access this directory';
        _isLoading = false;
      });
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

  void _showSortOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? ZWColors.darkSurface : ZWColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('SORT BY', style: GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 3, color: accent,
              )),
              const SizedBox(height: 16),
              _sortTile(ctx, LucideIcons.arrowDownAZ, 'Name', _SortMode.name, accent),
              _sortTile(ctx, LucideIcons.arrowDown01, 'Size', _SortMode.size, accent),
              _sortTile(ctx, LucideIcons.calendarDays, 'Date Modified', _SortMode.date, accent),
              const Divider(),
              ListTile(
                leading: Icon(_showHidden ? LucideIcons.eye : LucideIcons.eyeOff,
                    color: _showHidden ? accent : null, size: 20),
                title: Text(
                  _showHidden ? 'Hide Hidden Files' : 'Show Hidden Files',
                  style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: _showHidden ? FontWeight.w700 : FontWeight.w500,
                    color: _showHidden ? accent : null,
                  ),
                ),
                onTap: () {
                  setState(() => _showHidden = !_showHidden);
                  Navigator.pop(ctx);
                  _loadDirectory(_currentDir);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(BuildContext ctx, IconData icon, String label, _SortMode mode, Color accent) {
    final isActive = _sortMode == mode;
    return ListTile(
      leading: Icon(icon, color: isActive ? accent : null, size: 20),
      title: Text(label, style: GoogleFonts.manrope(
        fontSize: 14, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        color: isActive ? accent : null,
      )),
      trailing: isActive ? Icon(Icons.check, color: accent, size: 18) : null,
      onTap: () {
        setState(() => _sortMode = mode);
        Navigator.pop(ctx);
        _loadDirectory(_currentDir);
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    return Column(
      children: [
        // ── Breadcrumb controls ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
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
                                    color: isLast ? accent : theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                if (!isLast) ...[
                                  const SizedBox(width: 4),
                                  Icon(LucideIcons.chevronRight,
                                      size: 12,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showSortOptions,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accent.withValues(alpha: 0.15)),
                  ),
                  child: Icon(LucideIcons.arrowUpDown, color: accent, size: 16),
                ),
              ),
            ],
          ),
        ),

        // ── File list ──
        Expanded(
          child: _buildBody(theme, isDark, accent),
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark, Color accent) {
    if (!_hasPermission) {
      return Center(
        child: ElevatedButton(
          onPressed: _checkPermissions,
          child: const Text('Grant Storage Permission'),
        ),
      );
    }

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accent));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.folderX, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!, textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(color: theme.colorScheme.onSurfaceVariant)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _goUp, child: const Text('Go Back')),
          ],
        ),
      );
    }

    if (_entries.isEmpty) {
      return Center(child: Text('Folder is empty',
          style: GoogleFonts.manrope(color: theme.colorScheme.onSurfaceVariant)));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
      cacheExtent: 500,
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final meta = _entries[index];
        final isSelected = widget.selectedFiles.contains(meta.entity.path);

        return RepaintBoundary(
          child: _FileListTile(
          meta: meta,
          isSelected: isSelected,
          formatSize: _formatSize,
          onTap: () {
            if (meta.isDir) {
              _navigateTo(meta.entity as Directory);
            } else {
              widget.onToggle(meta.entity.path);
            }
          },
          onLongPress: !meta.isDir ? () => widget.onToggle(meta.entity.path) : null,
          accent: accent,
          isDark: isDark,
        ),
      );
      },
    );
  }
}

class _FileListTile extends StatelessWidget {
  final _EntryMeta meta;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color accent;
  final bool isDark;
  final String Function(int) formatSize;

  const _FileListTile({
    required this.meta,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    required this.accent,
    required this.isDark,
    required this.formatSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon = meta.isDir ? LucideIcons.folder : LucideIcons.file;
    Color iconColor = meta.isDir ? Colors.amber : Colors.blueGrey;

    final ext = meta.name.split('.').last.toLowerCase();
    if (!meta.isDir) {
      if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext)) {
        icon = LucideIcons.image;
        iconColor = Colors.green;
      } else if (['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext)) {
        icon = LucideIcons.video;
        iconColor = Colors.purple;
      } else if (['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'].contains(ext)) {
        icon = LucideIcons.music;
        iconColor = Colors.pink;
      } else if (ext == 'apk') {
        icon = LucideIcons.box;
        iconColor = Colors.orange;
      } else if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'pptx'].contains(ext)) {
        icon = LucideIcons.fileText;
        iconColor = Colors.blue;
      } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
        icon = LucideIcons.archive;
        iconColor = Colors.teal;
      }
    }

    // Build subtitle: extension + size for files, "Folder" for dirs
    String subtitle;
    if (meta.isDir) {
      subtitle = 'Folder';
    } else {
      subtitle = ext.toUpperCase();
      if (meta.size > 0) {
        subtitle += '  •  ${formatSize(meta.size)}';
      }
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
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
            color: isSelected ? accent.withValues(alpha: 0.35) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildPreview(icon, iconColor, ext),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meta.name,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? accent : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (meta.isDir)
              Icon(LucideIcons.chevronRight, size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4))
            else
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

  Widget _buildPreview(IconData defaultIcon, Color defaultColor, String ext) {
    if (meta.isDir) return Icon(defaultIcon, color: defaultColor, size: 22);

    if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext)) {
      return Image.file(
        File(meta.entity.path),
        fit: BoxFit.cover,
        cacheWidth: 88, // Limit decode resolution to prevent memory issues
        errorBuilder: (context, error, stackTrace) => Icon(defaultIcon, color: defaultColor, size: 22),
      );
    } else if (['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext)) {
      return _VideoThumbnailWidget(
        path: meta.entity.path,
        defaultIcon: defaultIcon,
        defaultColor: defaultColor,
      );
    }

    return Icon(defaultIcon, color: defaultColor, size: 22);
  }
}

class _VideoThumbnailWidget extends StatefulWidget {
  final String path;
  final IconData defaultIcon;
  final Color defaultColor;

  const _VideoThumbnailWidget({
    required this.path,
    required this.defaultIcon,
    required this.defaultColor,
  });

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  Uint8List? _thumbData;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    try {
      final uint8list = await VideoThumbnail.thumbnailData(
        video: widget.path,
        imageFormat: ImageFormat.WEBP,
        maxWidth: 88,
        quality: 20,
      );
      if (mounted) {
        setState(() => _thumbData = uint8list);
      }
    } catch (_) {
      // Silently fail — icon fallback is fine
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbData != null) {
      return Image.memory(
        _thumbData!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(widget.defaultIcon, color: widget.defaultColor, size: 22),
      );
    }
    return Icon(widget.defaultIcon, color: widget.defaultColor, size: 22);
  }
}
