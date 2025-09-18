import 'package:flutter/material.dart';

class GradientBorderContainer extends StatelessWidget {
  final Widget child;
  final LinearGradient gradient;
  final Color backgroundColor;
  final double borderWidth;
  final double borderRadius;
  final double width;
  final double height;

  const GradientBorderContainer({
    super.key,
    required this.child,
    required this.gradient,
    required this.height,
    required this.width,
    this.backgroundColor = const Color(0xFF1A1A1A),
    this.borderWidth = 1.5,
    this.borderRadius = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // The overall container to define the size of the widget
      width: width,
      height: height,
      margin: const EdgeInsets.all(8),
      child: Stack(
        children: [
          // 1. The full gradient border container
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: gradient,
            ),
          ),
          // 2. The central 'mask' that hides the center part of the left and right borders
          Center(
            child: Container(
              height: 50,
              width: 150,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(borderRadius - borderWidth),
              ),
            ),
          ),
          // 3. The inner content container, which hosts the child
          Container(
            margin: EdgeInsets.all(borderWidth),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius - borderWidth),
            ),
            child: Center(
              child: child, // The child widget passed to this class
            ),
          ),
        ],
      ),
    );
  }
}