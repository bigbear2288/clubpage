import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  print('Dart main() started!');
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Text(
          'Hello World!',
          style: TextStyle(fontSize: 24, color: Colors.red),
        ),
      ),
    ),
  ));
}
