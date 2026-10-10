import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

enum _DateSort { newestFirst, oldestFirst }
enum _FormatFilter { all, photosOnly, videosOnly }

class GalleryTab extends StatefulWidget {
  final Set<String> selectedFiles;
  final Function(String path) onToggle;

  const GalleryTab({
    super.key,
    required this.selectedFiles,
    required this.onToggle,
  });

  @override
  State<GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<GalleryTab> with AutomaticKeepAliveClientMixin {
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;
  List<AssetEntity> _allMedia = [];
  List<AssetEntity> _filteredMedia = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  String _currentAlbumName = 'All Media';
  int _currentAlbumCount = 0;

  _DateSort _dateSort = _DateSort.newestFirst;
  _FormatFilter _formatFilter = _FormatFilter.all;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth || ps.hasAccess) {
      if (!mounted) return;
      setState(() => _hasPermission = true);

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );

      if (albums.isEmpty) {
        if (!mounted) return;
        setState(() {
          _albums = [];
          _allMedia = [];
          _filteredMedia = [];
          _isLoading = false;
        });
        return;
      }

      albums.sort((a, b) {
        if (a.isAll) return -1;
        if (b.isAll) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      if (!mounted) return;
      setState(() {
        _albums = albums;
        _currentAlbum = albums.first;
        _currentAlbumName = albums.first.isAll ? 'All Media' : albums.first.name;
      });

      await _loadAlbumMedia(albums.first);
    } else {
      PhotoManager.openSetting();
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAlbumMedia(AssetPathEntity album) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final count = await album.assetCountAsync;
    final List<AssetEntity> allAssets = [];
    const int pageSize = 200;
    int page = 0;
    while (allAssets.length < count) {
      final batch = await album.getAssetListPaged(page: page, size: pageSize);
      if (batch.isEmpty) break;
      allAssets.addAll(batch);
      page++;
    }

    if (!mounted) return;
    setState(() {
      _allMedia = allAssets;
      _currentAlbumCount = allAssets.length;
    });

    _applyFilters();
  }

  void _applyFilters() {
    List<AssetEntity> result = List.from(_allMedia);

    switch (_formatFilter) {
      case _FormatFilter.photosOnly:
        result = result.where((a) => a.type == AssetType.image).toList();
        break;
      case _FormatFilter.videosOnly:
        result = result.where((a) => a.type == AssetType.video).toList();
        break;
      case _FormatFilter.all:
        break;
    }

    switch (_dateSort) {
      case _DateSort.newestFirst:
        result.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        break;
      case _DateSort.oldestFirst:
        result.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
        break;
    }

    if (!mounted) return;
    setState(() {
      _filteredMedia = result;
      _isLoading = false;
    });
  }

  /// Smooth animated album picker bottom sheet
  void _showAlbumPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: isDark ? ZWColors.darkSurface : ZWColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(LucideIcons.folderOpen, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Text('SELECT ALBUM', style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2, color: accent,
                  )),
                ],
              ),
            ),
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.2)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _albums.length,
                itemBuilder: (ctx, index) {
                  final album = _albums[index];
                  final isActive = album == _currentAlbum;
                  final name = album.isAll ? 'All Media' : album.name;

                  return FutureBuilder<int>(
                    future: album.assetCountAsync,
                    builder: (ctx, snap) {
                      final count = snap.data ?? 0;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            if (album != _currentAlbum) {
                              setState(() {
                                _currentAlbum = album;
                                _currentAlbumName = name;
                              });
                              _loadAlbumMedia(album);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? accent.withValues(alpha: 0.15)
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isActive ? LucideIcons.folderOpen : LucideIcons.folder,
                                    color: isActive ? accent : Theme.of(context).colorScheme.onSurfaceVariant,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.manrope(
                                      fontSize: 14,
                                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                      color: isActive ? accent : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$count',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 10),
                                  Icon(Icons.check_circle, color: accent, size: 20),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? ZWColors.darkSurface : ZWColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
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
                  Text('SORT & FILTER', style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 3, color: accent,
                  )),
                  const SizedBox(height: 16),

                  Text('Date', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _filterChip('Newest first', _dateSort == _DateSort.newestFirst, accent, () {
                        setSheetState(() => _dateSort = _DateSort.newestFirst);
                      }),
                      const SizedBox(width: 8),
                      _filterChip('Oldest first', _dateSort == _DateSort.oldestFirst, accent, () {
                        setSheetState(() => _dateSort = _DateSort.oldestFirst);
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text('Format', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _filterChip('All', _formatFilter == _FormatFilter.all, accent, () {
                        setSheetState(() => _formatFilter = _FormatFilter.all);
                      }),
                      const SizedBox(width: 8),
                      _filterChip('Photos', _formatFilter == _FormatFilter.photosOnly, accent, () {
                        setSheetState(() => _formatFilter = _FormatFilter.photosOnly);
                      }),
                      const SizedBox(width: 8),
                      _filterChip('Videos', _formatFilter == _FormatFilter.videosOnly, accent, () {
                        setSheetState(() => _formatFilter = _FormatFilter.videosOnly);
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: isDark ? ZWColors.darkBackground : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _applyFilters();
                      },
                      child: Text('Apply', style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700, letterSpacing: 1,
                      )),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accent : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(label, style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? accent : Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;

    if (!_hasPermission && !_isLoading) {
      return Center(
        child: ElevatedButton(
          onPressed: _loadGallery,
          child: const Text('Grant Gallery Permission'),
        ),
      );
    }

    return Column(
      children: [
        // ── Album selector + filter button ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Album picker button (replaces DropdownButton)
              Expanded(
                child: GestureDetector(
                  onTap: _showAlbumPicker,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.folder, size: 14, color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_currentAlbumName ($_currentAlbumCount)',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12, fontWeight: FontWeight.w600, color: accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(LucideIcons.chevronDown, size: 14, color: accent),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Icon(LucideIcons.slidersHorizontal, color: accent, size: 16),
                ),
              ),
            ],
          ),
        ),

        // ── Content ──
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2.5))
              : _filteredMedia.isEmpty
                  ? Center(child: Text('No media found', style: GoogleFonts.manrope(
                      color: theme.colorScheme.onSurfaceVariant)))
                  : GridView.builder(
                      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 100, top: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 3,
                        mainAxisSpacing: 3,
                      ),
                      cacheExtent: 500,
                      itemCount: _filteredMedia.length,
                      itemBuilder: (context, index) {
                        final asset = _filteredMedia[index];
                        return RepaintBoundary(
                          child: _GalleryTile(
                            asset: asset,
                            selectedFiles: widget.selectedFiles,
                            onToggle: widget.onToggle,
                            accent: accent,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _GalleryTile extends StatefulWidget {
  final AssetEntity asset;
  final Set<String> selectedFiles;
  final Function(String) onToggle;
  final Color accent;

  const _GalleryTile({
    required this.asset,
    required this.selectedFiles,
    required this.onToggle,
    required this.accent,
  });

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  Uint8List? _thumbBytes;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Load thumbnail first (fast), then file path
    final thumb = await widget.asset.thumbnailDataWithSize(
      const ThumbnailSize(150, 150),
      quality: 80,
    );
    if (!mounted) return;
    setState(() => _thumbBytes = thumb);

    final file = await widget.asset.file;
    if (!mounted) return;
    setState(() => _filePath = file?.path);
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = _filePath != null && widget.selectedFiles.contains(_filePath);

    if (_thumbBytes == null) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return GestureDetector(
      onTap: _filePath != null ? () => widget.onToggle(_filePath!) : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: MemoryImage(_thumbBytes!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (widget.asset.type == AssetType.video)
            Positioned(
              bottom: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.play, color: Colors.white, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      _formatDuration(widget.asset.videoDuration),
                      style: GoogleFonts.manrope(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          if (isSelected)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: widget.accent.withValues(alpha: 0.35),
                border: Border.all(color: widget.accent, width: 2.5),
              ),
            ),
          if (isSelected)
            Positioned(
              top: 6, right: 6,
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: Icon(Icons.check_circle, color: widget.accent, size: 22),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}
