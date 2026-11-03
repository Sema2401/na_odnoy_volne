import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg = Color(0xFF05020B);
  static const Color surface = Color(0xFF0D0618);
  static const Color pink = Color(0xFFFF1ED2);
  static const Color violet = Color(0xFF8A2BE2);
  static const Color text = Color(0xFFF4EEFC);
  static const Color muted = Color(0xFFA999C4);
  static const Color line = Color(0x59BE50FF); // rgba(190,80,255,.35)

  static const LinearGradient grad = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [pink, violet],
  );

  static List<BoxShadow> get glow => [
        BoxShadow(
          color: pink.withValues(alpha: 0.45),
          blurRadius: 24,
          spreadRadius: 0,
        ),
      ];

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      // scaffoldBackgroundColor НЕ ЗАДАЁМ — чтобы был виден NeonBackground
      colorScheme: const ColorScheme.dark(
        primary: pink,
        secondary: violet,
        surface: surface,
        onPrimary: Colors.white,
        onSurface: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
        ),
        iconTheme: IconThemeData(color: text),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: pink,
        unselectedItemColor: muted,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: text,
        displayColor: text,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: pink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: pink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: pink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: line),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: pink),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: pink),
    );
  }
}

// ───────────────────────── Анимированный фон ─────────────────────────

class NeonBackground extends StatefulWidget {
  final Widget child;
  const NeonBackground({super.key, required this.child});

  @override
  State<NeonBackground> createState() => _NeonBackgroundState();
}

class _NeonBackgroundState extends State<NeonBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _sin(double x) => math.sin(x);
  double _cos(double x) => math.cos(x);

  Widget _blob({
    required double cx,
    required double cy,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(
            children: [
              Positioned(
                left: cx * w - size / 2,
                top: cy * h - size / 2,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF1ED2).withValues(alpha: opacity),
                        const Color(0xFF8A2BE2)
                            .withValues(alpha: opacity * 0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 * 3.141592653589793; // 0..2π

        return Stack(
          children: [
            // Градиентный фон: тёмно-синий → тёмно-фиолетовый
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF05020B), // почти чёрный с синим
                      Color(0xFF0A0420), // тёмно-синий
                      Color(0xFF1A0638), // тёмно-фиолетовый
                      Color(0xFF2A0645), // чуть светлее фиолетовый
                    ],
                    stops: [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // 4 розовых круга с прозрачностью и медленным движением
            _blob(
              cx: 0.15 + 0.08 * _sin(t),
              cy: 0.18 + 0.06 * _cos(t * 0.7),
              size: 320,
              opacity: 0.35,
            ),
            _blob(
              cx: 0.85 + 0.07 * _cos(t * 0.6),
              cy: 0.25 + 0.08 * _sin(t * 0.8),
              size: 280,
              opacity: 0.30,
            ),
            _blob(
              cx: 0.20 + 0.06 * _sin(t * 0.9 + 1.2),
              cy: 0.82 + 0.07 * _cos(t * 0.5 + 0.4),
              size: 360,
              opacity: 0.28,
            ),
            _blob(
              cx: 0.78 + 0.09 * _cos(t * 0.7 + 2.0),
              cy: 0.78 + 0.06 * _sin(t * 0.6 + 1.7),
              size: 300,
              opacity: 0.32,
            ),

            // Контент приложения поверх
            Positioned.fill(child: widget.child),
          ],
        );
      },
    );
  }
}