import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_service.dart';

import 'package:provider/provider.dart'; // Thêm import này

import 'auth_provider.dart'; // Thêm import này

class MonthlyCardsScreen extends StatefulWidget {
  const MonthlyCardsScreen({super.key});

  @override
  State<MonthlyCardsScreen> createState() => _MonthlyCardsScreenState();
}

class _MonthlyCardsScreenState extends State<MonthlyCardsScreen> {
  List<dynamic> cards = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCards();
  }

  void fetchCards() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/monthly_cards'),
      );
      if (res.statusCode == 200) {
        setState(() {
          cards = jsonDecode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Lỗi: $e");
    }
    setState(() => isLoading = false);
  }

  // === [MỚI] HÀM XÓA VÉ THÁNG (CHỈ ADMIN MỚI GỌI ĐƯỢC) ===
  void _deleteCard(String plate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hủy Vé Tháng"),
        content: Text(
          "Bạn có chắc muốn hủy vé tháng của xe $plate?\nHệ thống cũng sẽ xóa toàn bộ dữ liệu khuôn mặt liên quan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Đồng ý xóa",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final res = await http.delete(
        Uri.parse('${ApiService.baseUrl}/monthly_cards/$plate'),
      );
      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(data['message'])));
        fetchCards(); // Tải lại danh sách
      }
    }
  }
  // ======================================================

  @override
  Widget build(BuildContext context) {
    // Lấy quyền hiện tại
    final role = Provider.of<AuthProvider>(context, listen: false).role;

    return Scaffold(
      appBar: AppBar(title: const Text("Danh sách Thẻ Tháng")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.credit_card,
                      color: Colors.blue,
                      size: 40,
                    ),
                    title: Text(
                      card['plate'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      "Chủ hộ: ${card['owner']}\nSĐT: ${card['phone']}\nHết hạn: ${card['expiry']}",
                    ),
                    isThreeLine: true,
                    // === [MỚI] CHỈ ADMIN MỚI THẤY NÚT XÓA ===
                    trailing: role == 'Admin'
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_forever,
                              color: Colors.red,
                            ),
                            tooltip: 'Hủy vé tháng',
                            onPressed: () => _deleteCard(card['plate']),
                          )
                        : null,
                    // =========================================
                  ),
                );
              },
            ),
    );
  }
}
