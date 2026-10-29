import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_service.dart';

class AdminGuardsScreen extends StatefulWidget {
  const AdminGuardsScreen({super.key});
  @override
  State<AdminGuardsScreen> createState() => _AdminGuardsScreenState();
}

class _AdminGuardsScreenState extends State<AdminGuardsScreen> {
  List<dynamic> guards = [];

  @override
  void initState() {
    super.initState();
    _fetchGuards();
  }

  void _fetchGuards() async {
    final res = await http.get(Uri.parse('${ApiService.baseUrl}/admin/guards'));
    if (res.statusCode == 200) setState(() => guards = jsonDecode(res.body));
  }

  void _addGuardDialog() {
    final uCtrl = TextEditingController();
    final pCtrl = TextEditingController();
    final nCtrl = TextEditingController();
    final phCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Thêm Bảo vệ mới"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uCtrl,
                decoration: const InputDecoration(labelText: "Tên đăng nhập"),
              ),
              TextField(
                controller: pCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Mật khẩu"),
              ),
              TextField(
                controller: nCtrl,
                decoration: const InputDecoration(labelText: "Họ tên"),
              ),
              TextField(
                controller: phCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Số điện thoại"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              final res = await http.post(
                Uri.parse('${ApiService.baseUrl}/admin/add_guard'),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode({
                  "username": uCtrl.text,
                  "password": pCtrl.text,
                  "fullname": nCtrl.text,
                  "phone": phCtrl.text,
                }),
              );
              final data = jsonDecode(res.body);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(data['message'])));
                if (data['success']) _fetchGuards();
              }
            },
            child: const Text("Thêm"),
          ),
        ],
      ),
    );
  }

  void _deleteGuard(String username) async {
    await http.delete(
      Uri.parse('${ApiService.baseUrl}/admin/delete_guard/$username'),
    );
    _fetchGuards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý Bảo vệ")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGuardDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: guards.length,
        itemBuilder: (context, index) {
          final g = guards[index];
          return Card(
            child: ListTile(
              leading: const Icon(
                Icons.security,
                color: Colors.orange,
                size: 35,
              ),
              title: Text(
                g['fullname'] ?? g['username'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("Username: ${g['username']}\nSĐT: ${g['phone']}"),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteGuard(g['username']),
              ),
            ),
          );
        },
      ),
    );
  }
}
