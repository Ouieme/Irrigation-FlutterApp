import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:irrigo/pages/home_page.dart';
import 'package:irrigo/pages/main_page.dart';

import '../auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? errorMessage = '';
  bool isLogin = true;
  bool _obscurePassword = true;

  final TextEditingController _controllerEmail = TextEditingController();
  final TextEditingController _controllerPassword = TextEditingController();

  Future<void> signInWithEmailAndPassword() async {
    try {
      await Auth().signInWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }

  Future<void> createUserWithEmailAndPassword() async {
    try {
      await Auth().createUserWithEmailAndPassword(
        email: _controllerEmail.text,
        password: _controllerPassword.text,
      );

      if (context.mounted) {
        // Affiche un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account successfully created!"),
            backgroundColor: Colors.green,
          ),
        );

        // Revenir automatiquement en mode "Login"
        setState(() {
          isLogin = true;
          errorMessage = '';
        });
      }

    } on FirebaseAuthException catch (e) {
      setState(() {
        errorMessage = e.message;
      });
    }
  }



  Widget _entryField(
    String hint,
    TextEditingController controller, {
    bool obscure = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure ? _obscurePassword : false,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          suffixIcon:
              obscure
                  ? IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  )
                  : null,
        ),
      ),
    );
  }

  Widget _errorMessage() {
    return errorMessage == ''
        ? const SizedBox.shrink()
        : Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '⚠️ $errorMessage',
            style: const TextStyle(color: Colors.red),
          ),
        );
  }

  Widget _submitButton() {
    return ElevatedButton(
      onPressed:
          isLogin ? signInWithEmailAndPassword : createUserWithEmailAndPassword,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromRGBO(0, 150, 136, 1),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      child: Text(isLogin ? 'LOGIN' : 'REGISTER'),
    );
  }

  Widget _loginOrRegisterButton() {
    return TextButton(
      onPressed: () {
        setState(() {
          isLogin = !isLogin;
          errorMessage = '';
        });
      },
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black),
          children: [
            TextSpan(
              text:
                  isLogin
                      ? "Don't have an account? "
                      : "Already have an account? ",
            ),
            TextSpan(
              text: isLogin ? "Register!" : "Login!",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(0, 150, 136, 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Image.asset('assets/images/main_chat.png', height: 250),
              const Text(
                "Welcome to IrrigoSmart !",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Keep your data safe",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              _entryField('Email', _controllerEmail),
              _entryField('Password', _controllerPassword, obscure: true),
              const SizedBox(height: 12),
              _errorMessage(),
              _submitButton(),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  // TODO: Forgot password action
                },
                child: const Text(
                  "Forgot password?",
                  style: TextStyle(color: Color.fromRGBO(0, 150, 136, 1)),
                ),
              ),
              const SizedBox(height: 8),
              _loginOrRegisterButton(),
            ],
          ),
        ),
      ),
    ),
  );
}

}
