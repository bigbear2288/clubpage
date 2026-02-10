import 'package:flutter/material.dart';
import 'pages/discovery_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/discovery_page.dart';
import 'pages/login_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Clubs App',
      theme: ThemeData(primarySwatch: Colors.red),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          print('DEBUG - Connection state: ${snapshot.connectionState}');
          print('DEBUG - Has data: ${snapshot.hasData}');
          print('DEBUG - User: ${snapshot.data}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData) {
            return MainNavigation();
          }

          return const LoginPage();
        },
      ),
    );
  }
}