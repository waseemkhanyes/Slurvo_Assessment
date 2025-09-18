import 'package:flutter/material.dart';
import 'gradient_border_container.dart'; // Import the new widget

class CustomizeOptionView extends StatelessWidget {

  const CustomizeOptionView({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the gradient you want to use
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

    // Use the new GradientBorderContainer and pass the content as the child
    return GradientBorderContainer(
      height: 48,
        width: double.infinity,
      gradient: cardGradient,
      // The child is the entire content you want inside the card
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: const [
            Text("Customize", style: TextStyle(fontSize: 16)),
            Spacer(),
            Icon(Icons.tune),
          ],
        ),
      ),
    );
  }
}