import 'package:firebase_auth/firebase_auth.dart';
import 'package:irrigo/pages/login_registre_page.dart';
import 'package:flutter/material.dart';
import 'package:irrigo/auth.dart';
import 'package:irrigo/pages/home_page.dart';
import 'package:irrigo/pages/main_page.dart';


class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: Auth().authStateChanges,
      builder: (context, snapshot) {
        print("Auth State: ${snapshot.connectionState} / ${snapshot.data}");
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user != null) {
            return const MainPage();
          } else {
            return const LoginPage();
          }
        }

        // Pendant le chargement
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

}
