import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'auth_provider.dart';
import 'api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart'; // Import màn hình Đăng ký
import 'forgot_password_screen.dart'; // Import màn hình Quên mật khẩu

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  void _login() async {
    setState(() => _isLoading = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userCtrl.text,
          "password": _passCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);

      if (data['success']) {
        if (mounted) {
          Provider.of<AuthProvider>(
            context,
            listen: false,
          ).login(data['username'], data['role']);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(data['message'])));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Lỗi kết nối Server!")));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_parking, size: 100, color: Colors.blue),
              const Text(
                "SMART PARKING AI",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _userCtrl,
                decoration: const InputDecoration(
                  labelText: "Tài khoản",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Mật khẩu",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),

              // Nút Đăng nhập
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: _login,
                      child: const Text("ĐĂNG NHẬP"),
                    ),

              const SizedBox(height: 15),

              // Nút Quên mật khẩu (Nằm trên cùng bên ngoài)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: const Text(
                  "Quên mật khẩu?",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 5),

              // Nút Đăng ký
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
                child: const Text(
                  "Chưa có tài khoản? Đăng ký ngay (Từ 18 tuổi)",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
