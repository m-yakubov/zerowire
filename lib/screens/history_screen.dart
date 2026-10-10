import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/transfer_service.dart';
import '../widgets/glass_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final transfer = context.watch<TransferService>();
    final accent = isDark ? ZWColors.neonCyan : ZWColors.primaryDark;
    final history = transfer.history;

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
                StatusPulse(label: 'History', color: ZWColors.neonCyan),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'RECENT TRANSFERS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 16),

            // Transfer list
            Expanded(
              child: history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.inbox,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transfers yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Send or receive files to see them here.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: history.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final record = history[index];
                        final isSent = record.type == TransferType.sent;
                        final isExpanded = _expandedIndex == index;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedIndex = isExpanded ? null : index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutCubic,
                            child: GlassCard(
                              padding: const EdgeInsets.all(16),
                              borderRadius: BorderRadius.circular(20),
                              child: Column(
                                children: [
                                  // Main row
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: (isSent ? accent : ZWColors.neonPurple)
                                              .withValues(alpha: 0.12),
                                        ),
                                        child: Icon(
                                          isSent
                                              ? LucideIcons.arrowUpCircle
                                              : LucideIcons.arrowDownCircle,
                                          size: 22,
                                          color: isSent
                                              ? accent
                                              : (isDark
                                                  ? ZWColors.neonPurple
                                                  : const Color(0xFF9C27B0)),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              record.fileName,
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${record.formattedSize} • ${record.formattedTime}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(100),
                                          color: (isSent ? accent : ZWColors.neonPurple)
                                              .withValues(alpha: 0.1),
                                        ),
                                        child: Text(
                                          isSent ? 'SENT' : 'RECEIVED',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: isSent
                                                ? accent
                                                : (isDark
                                                    ? ZWColors.neonPurple
                                                    : const Color(0xFF9C27B0)),
                                            fontSize: 9,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Expandable details
                                  AnimatedCrossFade(
                                    duration: const Duration(milliseconds: 250),
                                    crossFadeState: isExpanded
                                        ? CrossFadeState.showSecond
                                        : CrossFadeState.showFirst,
                                    firstChild: const SizedBox.shrink(),
                                    secondChild: _buildExpandedDetails(
                                      context, record, theme, isDark, accent,
                                    ),
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
        ),
      ),
    );
  }

  Widget _buildExpandedDetails(
    BuildContext context,
    TransferRecord record,
    ThemeData theme,
    bool isDark,
    Color accent,
  ) {
    final hasPath = record.filePath != null && record.filePath!.isNotEmpty;
    final fileExists = hasPath && File(record.filePath!).existsSync();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 14),

          // File location
          if (hasPath) ...[
            Text(
              'FILE LOCATION',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.folderOpen,
                    size: 14,
                    color: accent.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.filePath!,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Open file button
          if (hasPath && fileExists)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  OpenFilex.open(record.filePath!);
                },
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: Text(
                  'OPEN FILE',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: isDark ? ZWColors.darkBackground : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            )
          else if (hasPath && !fileExists)
            Text(
              'File no longer exists on device.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: Colors.red.shade300,
              ),
            ),
        ],
      ),
    );
  }
}
