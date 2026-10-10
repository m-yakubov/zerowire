import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A frosted glass card matching the Design 2 glassmorphism spec.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? borderColor;
  final double blur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.borderColor,
    this.blur = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? ZWColors.darkSurfaceVariant.withValues(alpha: 0.4)
        : ZWColors.lightSurface.withValues(alpha: 0.7);
    final border = borderColor ?? (isDark
        ? ZWColors.darkOutlineVariant.withValues(alpha: 0.2)
        : ZWColors.lightOutlineVariant.withValues(alpha: 0.3));

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius,
            border: Border.all(color: border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A glowing neon-bordered card used for the Home screen action buttons.
class NeonActionCard extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCyan; // true = cyan glow, false = purple glow

  const NeonActionCard({
    super.key,
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isCyan = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isCyan ? ZWColors.neonCyan : ZWColors.neonPurple;
    final lightAccent = isCyan ? ZWColors.primaryDark : const Color(0xFF9C27B0);
    final color = isDark ? accentColor : lightAccent;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        child: GlassCard(
          borderColor: color.withValues(alpha: isDark ? 0.25 : 0.3),
          borderRadius: BorderRadius.circular(28),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.25),
                      color.withValues(alpha: 0.05),
                    ],
                  ),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 20,
                            spreadRadius: 1,
                          ),
                        ],
                ),
                child: Icon(icon, size: 36, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color.withValues(alpha: 0.6),
                      letterSpacing: 2.0,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing status dot indicator
class StatusPulse extends StatelessWidget {
  final Color color;
  final String label;

  const StatusPulse({
    super.key,
    this.color = ZWColors.neonCyan,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = isDark ? color : ZWColors.primaryDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: effectiveColor),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: effectiveColor,
                  letterSpacing: 2.0,
                ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.5 + _controller.value * 0.5),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.4 * _controller.value),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}
