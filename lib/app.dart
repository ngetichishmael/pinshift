import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinshift/presentation/home_page.dart';

class PinshiftApp extends StatelessWidget {
  const PinshiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinshift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5AC8FA),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class PinshiftRoot extends StatelessWidget {
  const PinshiftRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: PinshiftApp());
  }
}
