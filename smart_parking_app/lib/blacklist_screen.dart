import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_service.dart';

import 'package:provider/provider.dart';

import 'auth_provider.dart';

class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  List<dynamic> blacklist = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBlacklist();
  }

  // Lấy danh sách từ Server
  void fetchBlacklist() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse('${ApiService.baseUrl}/blacklist'));
      if (res.statusCode == 200) {
        setState(() {
          blacklist = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Lỗi: $e");
    }
    setState(() => isLoading = false);
  }

  // Hàm gọi API xóa xe (CHỈ ADMIN DÙNG)
  void _deleteItem(String plate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận"),
        content: Text("Bạn có chắc muốn xóa xe $plate khỏi Sổ Đen?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Xóa", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await http.delete(
        Uri.parse('${ApiService.baseUrl}/blacklist/$plate'),
      );
      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(data['message'])));
        fetchBlacklist(); // Tải lại danh sách
      }
    }
  }

  // Hiển thị hộp thoại thêm xe
  void _showAddDialog() {
    final plateCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final username = Provider.of<AuthProvider>(context, listen: false).username;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Thêm xe vào Sổ Đen"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: plateCtrl,
              decoration: const InputDecoration(labelText: "Biển số xe"),
            ),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(labelText: "Lý do (Bắt buộc)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (plateCtrl.text.isNotEmpty && reasonCtrl.text.isNotEmpty) {
                final res = await http.post(
                  Uri.parse('${ApiService.baseUrl}/blacklist'),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "plate": plateCtrl.text,
                    "reason": reasonCtrl.text,
                    "added_by": username,
                  }),
                );
                Navigator.pop(ctx);
                fetchBlacklist(); // Tải lại danh sách
              }
            },
            child: const Text("Thêm"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context, listen: false).role;

    return Scaffold(
      appBar: AppBar(title: const Text("Sổ Đen (Blacklist)")),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: blacklist.length,
              itemBuilder: (context, index) {
                final item = blacklist[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.warning, color: Colors.red),
                    title: Text(
                      item['plate'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      "Lý do: ${item['reason']}\nNgười thêm: ${item['added_by']}",
                    ),
                    isThreeLine: true,
                    // CHỈ ADMIN MỚI THẤY NÚT XÓA
                    trailing: role == 'Admin'
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteItem(item['plate']),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
