import 'package:flutter/material.dart';
import 'gradient_border_container.dart'; // Import the new widget

class AnalysisCardView extends StatelessWidget {
  final String title;
  final String value;
  final String unit;

  const AnalysisCardView({super.key, required this.title, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final LinearGradient cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.3),
        Colors.white.withOpacity(0.3),
        Colors.white.withOpacity(0.3),
        Colors.white.withOpacity(0.3),
      ],
      stops: const [0.4, 0.4, 0.6, 1.0],
    );

    return GradientBorderContainer(
      height: 100,
      width: (MediaQuery.of(context).size.width - 76) / 2,
      gradient: cardGradient,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}