import 'package:flutter/material.dart';

import 'src/viewer_screen.dart';

void main() {
  runApp(const _ViewerApp());
}

final class _ViewerApp extends StatelessWidget {
  const _ViewerApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ViewerScreen(),
    );
  }
}
