import 'package:flutter/material.dart';
import 'screens/test_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MTDSTestApp());
}

class MTDSTestApp extends StatelessWidget {
  const MTDSTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MTDS SDK Client Test',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const TestScreen(),
    );
  }
}
