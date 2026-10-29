import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_service.dart';

class AdminVisitorsScreen extends StatefulWidget {
  const AdminVisitorsScreen({super.key});

  @override
  State<AdminVisitorsScreen> createState() => _AdminVisitorsScreenState();
}

class _AdminVisitorsScreenState extends State<AdminVisitorsScreen> {
  List<dynamic> visitors = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllVisitors();
  }

  void _fetchAllVisitors() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/visitors/all'),
      );
      if (res.statusCode == 200) {
        setState(() => visitors = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint("Lỗi: $e");
    }
    setState(() => isLoading = false);
  }

  void _deleteVisitor(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hủy đơn khách"),
        content: const Text(
          "Bạn có chắc muốn hủy đơn khách này? Hành động này không thể hoàn tác.",
        ),
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
        Uri.parse('${ApiService.baseUrl}/visitors/$id'),
      );
      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(data['message'])));
        _fetchAllVisitors();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý Khách vãng lai")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : visitors.isEmpty
          ? const Center(child: Text("Không có dữ liệu khách."))
          : ListView.builder(
              itemCount: visitors.length,
              itemBuilder: (context, index) {
                final v = visitors[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.person_pin_circle,
                      color: Colors.blue,
                      size: 35,
                    ),
                    title: Text(
                      v['guest_name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      "Chủ hộ: ${v['host_plate']}\nBiển số khách: ${(v['guest_plate'] == null || v['guest_plate'] == '') ? 'Đi bộ' : v['guest_plate']}",
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      tooltip: "Hủy đơn khách",
                      onPressed: () => _deleteVisitor(v['id']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
