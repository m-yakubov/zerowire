import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsSpeedChart extends StatelessWidget {
  final double currentSpeedMBps;
  final String eta;
  final List<double> speedHistory;
  final Color accentColor;

  const AnalyticsSpeedChart({
    super.key,
    required this.currentSpeedMBps,
    required this.eta,
    required this.speedHistory,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (speedHistory.isEmpty) return const SizedBox.shrink();

    // Find the max speed for the Y axis maximum. We ensure it's at least 1.0 to avoid flatlines on 0.
    double maxSpeed = speedHistory.reduce((a, b) => a > b ? a : b);
    if (maxSpeed < 1.0) maxSpeed = 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Speed & ETA Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPEED',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: accentColor.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${currentSpeedMBps.toStringAsFixed(1)} MB/s',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'ETA',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: accentColor.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  eta,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Live Speed Graph
        SizedBox(
          height: 80,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (speedHistory.length - 1).toDouble(),
              minY: 0,
              maxY: maxSpeed * 1.2, // Add 20% padding to the top
              lineTouchData: const LineTouchData(enabled: false), // Disable touch interactions for performance
              lineBarsData: [
                LineChartBarData(
                  spots: speedHistory.asMap().entries.map((e) {
                    return FlSpot(e.key.toDouble(), e.value);
                  }).toList(),
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: accentColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.3),
                        accentColor.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
