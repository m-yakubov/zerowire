import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _pulseController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _textFadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Core Entrance Animation
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Continuous Pulse Animation for P2P vibe
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: false);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack), 
      ),
    );
    
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeIn),
      ),
    );

    _introController.forward();

    // Transition to HomeScreen safely after full animation
    Timer(const Duration(milliseconds: 3800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation.drive(CurveTween(curve: Curves.easeInCubic)),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 900),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pure black background minimizes the visual seam of the logo's black background
    final backgroundColor = Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dynamic Tech Grid Background (Subtle)
          Opacity(
            opacity: 0.03,
            child: CustomPaint(
              painter: _GridPainter(color: ZWColors.neonCyan),
            ),
          ),

          // Glowing Orbs
          Positioned(
            top: -100,
            left: -150,
            child: _buildGlowingOrb(ZWColors.neonCyan, 400),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: _buildGlowingOrb(ZWColors.neonPurple, 350),
          ),
          
          Center(
            child: AnimatedBuilder(
              animation: _introController,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Fixed dimension to prevent the pulse from expanding the Stack and causing the layout to shift downwards
                        const SizedBox(width: 130, height: 130),
                        // P2P Radar Pulse Effect around logo
                        Positioned.fill(
                          child: OverflowBox(
                            maxWidth: double.infinity,
                            maxHeight: double.infinity,
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final progress = _pulseController.value;
                                return Opacity(
                                  // Only show pulse after main entrance
                                  opacity: _introController.value > 0.5 ? (1.0 - progress) * 0.6 : 0.0, 
                                  child: Container(
                                    width: 140 + (progress * 150),
                                    height: 140 + (progress * 150),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: ZWColors.neonCyan.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            ),
                          ),
                        ),
                        // Main Animated Logo
                        Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: Hero(
                              tag: 'app_logo',
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: ZWColors.neonCyan.withOpacity(0.15 * _fadeAnimation.value),
                                      blurRadius: 60,
                                      spreadRadius: 10,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12), // Gentle curve that looks sharp and premium
                                  child: Image.asset(
                                    'assets/zerowire_logo.png',
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),

                    // Shimmering Text Reveal
                    Opacity(
                      opacity: _textFadeAnimation.value,
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [Colors.white, ZWColors.neonCyanLight, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds);
                        },
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Zer',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                  color: Colors.white,
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: _buildRadarO(),
                              ),
                              TextSpan(
                                text: 'Wire',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Subtitle with neon accent styling
                    Opacity(
                      opacity: _textFadeAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: ZWColors.neonCyan.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: ZWColors.neonCyan.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'ULTRA-FAST P2P',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.5,
                            color: ZWColors.neonCyan,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingOrb(Color color, double size) {
    return AnimatedBuilder(
      animation: _introController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value * 0.4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildRadarO() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 25,
          height: 25,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 6.0), 
          ),
          child: Transform.rotate(
            angle: _pulseController.value * 2 * pi,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white,
                  ],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
          ),
        );
      }
    );
  }
}

// Custom subtle tech-grid background
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    
    const double spacing = 40.0;
    
    // Draw vertical lines
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    
    // Draw horizontal lines
    for (double j = 0; j < size.height; j += spacing) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
