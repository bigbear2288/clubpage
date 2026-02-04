import 'package:flutter/material.dart';
<<<<<<<<< Temporary merge branch 1
=========
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/discovery_page.dart';
import 'pages/login_page.dart';
>>>>>>>>> Temporary merge branch 2

void main() {
  runApp(const MainApp());
}

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

          // Show loading while checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If user is logged in, show DiscoveryPage
          if (snapshot.hasData) {
            return const DiscoveryPage();
          }

          // Otherwise show LoginPage
          return const LoginPage();
        },
>>>>>>>>> Temporary merge branch 2
      ),
    );
  }
}
