import 'package:flutter/material.dart';

void main() {
  runApp(const BaitulMalApp());
}

class BaitulMalApp extends StatelessWidget {
  const BaitulMalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: "Baitul Mal Plus",
      home: Scaffold(body: Center(child: Text('Hello World'))),
      debugShowCheckedModeBanner: false,
    );
  }
}
