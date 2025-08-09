import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkSavedLogin();
  }

  Future<void> checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    final role = prefs.getString('role');
    final manfazName = prefs.getString('manfazName');

    if (savedUsername != null && role != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            username: savedUsername,
            role: role,
            manfazName: manfazName,
          ),
        ),
      );
    }
  }

  Future<void> login() async {
    var users = FirebaseFirestore.instance.collection('users');
    var query = await users
        .where('username', isEqualTo: usernameController.text.trim())
        .where('password', isEqualTo: passwordController.text.trim())
        .get();

    if (query.docs.isNotEmpty) {
      final userData = query.docs.first.data() as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', userData['username'] ?? '');
      await prefs.setString('role', userData['role'] ?? '');
      await prefs.setString('manfazName', userData['manfaz'] ?? '');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            username: userData['username'] ?? '',
            role: userData['role'] ?? '',
            manfazName: userData['manfaz'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بيانات خاطئة!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo.png',      // مسار اللوجو بتاعك
                width: 520,             // الحجم حسب ما ترغبين
                height: 200,
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 40),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  labelText: 'اسم المستخدم',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: 'كلمة السر',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.white,
                ),
                controller: passwordController,
                obscureText: true,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: login,
                  child: const Text('تسجيل دخول'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    backgroundColor: Colors.green, // استبدل primary بـ backgroundColor
                  ),
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}