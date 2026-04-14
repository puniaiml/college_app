import 'package:flutter/material.dart';

/// Displays a Focus Mode badge if the user has focus mode enabled
class FocusBadge extends StatelessWidget {
  final bool isFocusMode;
  final double size;

  const FocusBadge({
    required this.isFocusMode,
    this.size = 16,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (!isFocusMode) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: 'Focus Mode: User is concentrating',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: size * 0.5, vertical: size * 0.25),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * 0.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B6B).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.highlight, size: size, color: Colors.white),
            SizedBox(width: size * 0.3),
            Text(
              'Focus',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
