import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'admin_dashboard.dart';
import 'guard_dashboard.dart';
import 'driver_dashboard.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (auth.role == 'Admin') return const AdminDashboard();
    if (auth.role == 'Guard') return const GuardDashboard();
    if (auth.role == 'Driver') return const DriverDashboard();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Lỗi: Không xác định được quyền!"),
            ElevatedButton(
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text("Đăng xuất"),
            ),
          ],
        ),
      ),
    );
  }
}
