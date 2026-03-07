import 'package:flutter/material.dart';

import 'features/gym_map/presentation/gym_map_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.showMap = true});

  final bool showMap;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GymMap',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B7A60),
          surface: const Color(0xFFF1F8F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFEAF5F1),
        fontFamily: 'Trebuchet MS',
      ),
      home: GymMapPage(showMap: showMap),
    );
  }
}
