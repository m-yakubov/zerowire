import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';

enum _MusicSort { dateNewest, dateOldest, sizeLargest, sizeSmallest, nameAZ }

class MusicTab extends StatefulWidget {
  final Set<String> selectedFiles;
  final Function(String path) onToggle;

  const MusicTab({
    super.key,
    required this.selectedFiles,
    required this.onToggle,
  });

  @override
  State<MusicTab> createState() => _MusicTabState();
}

class _MusicTabState extends State<MusicTab> with AutomaticKeepAliveClientMixin {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  List<SongModel> _songs = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  _MusicSort _currentSort = _MusicSort.dateNewest;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool hasPermission = await _audioQuery.permissionsStatus();
    if (!hasPermission) {
      hasPermission = await _audioQuery.permissionsRequest();
    }

    if (hasPermission) {
      if (!mounted) return;
      setState(() => _hasPermission = true);
      _loadMusic();
    } else {
      if (!mounted) return;
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMusic() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    SongSortType sortType;
    OrderType orderType;

    switch (_currentSort) {
      case _MusicSort.dateNewest:
        sortType = SongSortType.DATE_ADDED;
        orderType = OrderType.DESC_OR_GREATER;
        break;
      case _MusicSort.dateOldest:
        sortType = SongSortType.DATE_ADDED;
        orderType = OrderType.ASC_OR_SMALLER;
        break;
      case _MusicSort.sizeLargest:
        sortType = SongSortType.SIZE;
        orderType = OrderType.DESC_OR_GREATER;
        break;
      case _MusicSort.sizeSmallest:
        sortType = SongSortType.SIZE;
        orderType = OrderType.ASC_OR_SMALLER;
        break;
      case _MusicSort.nameAZ:
        sortType = SongSortType.TITLE;
        orderType = OrderType.ASC_OR_SMALLER;
        break;
    }

    List<SongModel> songs = await _audioQuery.querySongs(
      sortType: sortType,
      orderType: orderType,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    if (!mounted) return;
    setState(() {
      _songs = songs;
      _isLoading = false;
    });
  }

  void _showSortSheet() {
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
              _sortTile(ctx, LucideIcons.calendarDays, 'Date (Newest first)', _MusicSort.dateNewest, accent),
              _sortTile(ctx, LucideIcons.calendarDays, 'Date (Oldest first)', _MusicSort.dateOldest, accent),
              _sortTile(ctx, LucideIcons.arrowDown01, 'Size (Largest first)', _MusicSort.sizeLargest, accent),
              _sortTile(ctx, LucideIcons.arrowDown01, 'Size (Smallest first)', _MusicSort.sizeSmallest, accent),
              _sortTile(ctx, LucideIcons.arrowDownAZ, 'Name (A-Z)', _MusicSort.nameAZ, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTile(BuildContext ctx, IconData icon, String label, _MusicSort sort, Color accent) {
    final isActive = _currentSort == sort;
    return ListTile(
      leading: Icon(icon, color: isActive ? accent : null, size: 20),
      title: Text(label, style: GoogleFonts.manrope(
        fontSize: 14, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        color: isActive ? accent : null,
      )),
      trailing: isActive ? Icon(Icons.check, color: accent, size: 18) : null,
      onTap: () {
        setState(() => _currentSort = sort);
        Navigator.pop(ctx);
        _loadMusic();
      },
    );
  }

  String _formatDuration(int? ms) {
    if (ms == null) return '';
    final d = Duration(milliseconds: ms);
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
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
          onPressed: _checkPermissions,
          child: const Text('Grant Music Permission'),
        ),
      );
    }

    return Column(
      children: [
        // ── Header row ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Current sort label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _isLoading ? 'Loading...' : '${_songs.length} tracks',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11, fontWeight: FontWeight.w700, color: accent,
                  ),
                ),
              ),
              const Spacer(),
              // Sort button
              GestureDetector(
                onTap: _showSortSheet,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.arrowUpDown, color: accent, size: 14),
                      const SizedBox(width: 6),
                      Text('Sort', style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, fontWeight: FontWeight.w600, color: accent,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── List ──
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: accent, strokeWidth: 2.5))
              : _songs.isEmpty
                  ? Center(child: Text('No music found', style: GoogleFonts.manrope(
                      color: theme.colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
                      cacheExtent: 500,
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        final path = song.data;
                        final isSelected = widget.selectedFiles.contains(path);

                        return RepaintBoundary(
                          child: GestureDetector(
                          onTap: () => widget.onToggle(path),
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
                                QueryArtworkWidget(
                                  id: song.id,
                                  type: ArtworkType.AUDIO,
                                  nullArtworkWidget: Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(LucideIcons.music, color: accent, size: 20),
                                  ),
                                  artworkWidth: 44,
                                  artworkHeight: 44,
                                  artworkBorder: BorderRadius.circular(10),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
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
                                              song.artist ?? 'Unknown',
                                              style: GoogleFonts.manrope(
                                                fontSize: 10,
                                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (song.duration != null) ...[
                                            Text(
                                              '  •  ${_formatDuration(song.duration)}',
                                              style: GoogleFonts.manrope(
                                                fontSize: 10,
                                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
                                          if (song.size > 0) ...[
                                            Text(
                                              '  •  ${_formatSize(song.size)}',
                                              style: GoogleFonts.manrope(
                                                fontSize: 10,
                                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                              ),
                                            ),
                                          ],
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
                        ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
