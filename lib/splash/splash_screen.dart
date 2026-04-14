import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shiksha_hub/auth/wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _textController;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textSlide;

  LottieComposition? _composition; // Store loaded composition

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadLottieAndStart(); // Single load + start sequence
  }

  Future<void> _loadLottieAndStart() async {
    // Load Lottie only if not already cached
    try {
      final data = await rootBundle.load('assets/lottie/splash.json');
      _composition = await LottieComposition.fromBytes(data.buffer.asUint8List());
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Lottie load error: $e');
    }

    _startAnimationSequence();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800), // Reduced from 3000ms
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700), // Reduced from 1200ms
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );

    _textSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );
  }

  Future<void> _startAnimationSequence() async {
    await _mainController.forward();
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 300)); // Reduced from 700ms

    if (mounted) _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const Wrapper(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400), // Reduced from 600ms
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final logoSize = isTablet ? size.width * 0.7 : size.width * 0.9;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _textController]),
        builder: (context, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromARGB(255, 113, 198, 255),
                  Color.fromARGB(255, 68, 189, 255),
                  Color.fromARGB(255, 49, 145, 255),
                  Color.fromARGB(255, 4, 176, 255),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: GridPatternPainter()),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo - no FutureBuilder inside AnimatedBuilder
                      Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: SizedBox(
                            width: logoSize,
                            height: logoSize,
                            child: _composition != null
                                ? Lottie(
                                    composition: _composition,
                                    fit: BoxFit.contain,
                                    repeat: false,
                                    options: LottieOptions(enableMergePaths: true),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),

                      SizedBox(height: isTablet ? 40 : 32),

                      // Main text
                      Opacity(
                        opacity: _textOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, _textSlide.value),
                          child: Text(
                            'Ignite Your Learning!',
                            style: TextStyle(
                              fontSize: isTablet
                                  ? size.width * 0.045
                                  : size.width * 0.062,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E3A8A),
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      SizedBox(height: isTablet ? 24 : 16),

                      // Subtitle
                      Opacity(
                        opacity: (_textOpacity.value * 0.8).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, _textSlide.value * 0.5),
                          child: Text(
                            'Empowering minds, shaping futures',
                            style: TextStyle(
                              fontSize: isTablet
                                  ? size.width * 0.025
                                  : size.width * 0.035,
                              fontWeight: FontWeight.w400,
                              color: const Color.fromARGB(255, 6, 32, 87),
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GridPatternPainter extends CustomPainter {
  const GridPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.08)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridSize = 60.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}