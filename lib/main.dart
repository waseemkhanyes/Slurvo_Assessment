// import 'package:flutter/material.dart';
// import 'package:slurvo/page/home/home_screen.dart';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Slurvo App',
//       theme: ThemeData.dark().copyWith(
//         scaffoldBackgroundColor: Colors.black,
//       ),
//       home: HomeScreen(),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:slurvo/page/start/start_screen.dart';  // Adjust path if necessary

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slurvo App',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const StartScreen(),
    );
  }
}

