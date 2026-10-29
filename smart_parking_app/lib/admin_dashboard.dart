import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'api_service.dart';

import 'package:intl/intl.dart';

import 'login_screen.dart';
import 'blacklist_screen.dart';
import 'monthly_cards_screen.dart';
import 'admin_visitors_screen.dart';
import 'admin_families_screen.dart';
import 'admin_users_screen.dart';
import 'user_header.dart'; // <-- Import Header mới
import 'admin_guards_screen.dart'; // <-- Import màn hình Quản lý Bảo vệ mới

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int revenue = 0;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

  @override
  void initState() {
    super.initState();
    _fetchRevenue();
  }

  void _fetchRevenue() async {
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/revenue'));
      final data = jsonDecode(res.body);
      setState(() {
        revenue = data['revenue'];
      });
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      // --- HEADER MỚI VỚI AVATAR ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: UserHeader(
          username: auth.username,
          role: 'Admin',
          onLogout: () {
            Provider.of<AuthProvider>(context, listen: false).logout();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- THẺ HIỂN THỊ DOANH THU ---
            Card(
              color: Colors.green.shade100,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Doanh thu hôm nay:",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      currencyFormat.format(revenue),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- HÀNG NÚT 1: SỔ ĐEN & THẺ THÁNG ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.block),
                    label: const Text("Sổ Đen"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BlacklistScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.blue.shade900,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.credit_card),
                    label: const Text("Thẻ Tháng"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MonthlyCardsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- CÁC NÚT CHỨC NĂNG KHÁC ---
            // 1. Quản lý Khách vãng lai
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade100,
                foregroundColor: Colors.purple.shade900,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.people_alt),
              label: const Text("Quản Lý Khách Vãng Lai"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminVisitorsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // 2. Quản lý Hộ gia đình
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade100,
                foregroundColor: Colors.teal.shade900,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.house),
              label: const Text("Quản Lý Hộ Gia Đình"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminFamiliesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),

            // 3. Quản lý Cư dân
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade100,
                foregroundColor: Colors.indigo.shade900,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.people),
              label: const Text("Quản Lý Cư Dân (Users)"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                );
              },
            ),
            const SizedBox(height: 10),

            // 4. NÚT MỚI: Quản lý Bảo vệ
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade100,
                foregroundColor: Colors.orange.shade900,
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.security),
              label: const Text("Quản Lý Bảo Vệ"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminGuardsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
