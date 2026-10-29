import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_service.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> users = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/users'),
      );
      if (res.statusCode == 200) {
        setState(() => users = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint("Lỗi: $e");
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Danh sách Cư dân")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final u = users[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: Icon(
                      u['role'] == 'Admin'
                          ? Icons.admin_panel_settings
                          : u['role'] == 'Guard'
                          ? Icons.security
                          : Icons.person,
                      color: u['role'] == 'Admin'
                          ? Colors.red
                          : (u['role'] == 'Guard'
                                ? Colors.orange
                                : Colors.blue),
                      size: 35,
                    ),
                    title: Text(
                      u['fullname'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      "Username: ${u['username']}\nVai trò: ${u['role']}\nHộ: ${u['family_id']} (${u['account_type']})",
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
