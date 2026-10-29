import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_service.dart';

class AdminFamiliesScreen extends StatefulWidget {
  const AdminFamiliesScreen({super.key});

  @override
  State<AdminFamiliesScreen> createState() => _AdminFamiliesScreenState();
}

class _AdminFamiliesScreenState extends State<AdminFamiliesScreen> {
  List<dynamic> families = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFamilies();
  }

  void _fetchFamilies() async {
    setState(() => isLoading = true);
    try {
      // Gọi API lấy danh sách hộ gia đình
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/families'),
      );
      if (res.statusCode == 200) {
        setState(() => families = jsonDecode(utf8.decode(res.bodyBytes)));
      }
    } catch (e) {
      debugPrint("Lỗi: $e");
    }
    setState(() => isLoading = false);
  }

  // HÀM MỚI: Xóa hộ gia đình
  void _deleteFamily(String familyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Cảnh báo nguy hiểm",
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          "Bạn có chắc chắn muốn xóa TOÀN BỘ hộ gia đình $familyId?\n\nHành động này sẽ xóa vĩnh viễn tài khoản của họ, thẻ tháng, khách đã khai báo và thành viên gia đình. Không thể hoàn tác!",
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
              "XÓA VĨNH VIỄN",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await http.delete(
          Uri.parse('${ApiService.baseUrl}/admin/families/$familyId'),
        );
        final data = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(data['message'])));
          _fetchFamilies(); // Tải lại danh sách sau khi xóa
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("Lỗi kết nối!")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý Hộ Gia đình")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : families.isEmpty
          ? const Center(child: Text("Chưa có dữ liệu hộ gia đình."))
          : ListView.builder(
              itemCount: families.length,
              itemBuilder: (context, index) {
                final fam = families[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  elevation: 3,
                  child: ListTile(
                    leading: const Icon(
                      Icons.home,
                      color: Colors.blue,
                      size: 40,
                    ),
                    title: Text(
                      "Mã Hộ: ${fam['family_id']}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text(
                          "Tổng số thành viên: ${fam['total_members']} người",
                        ),
                        Text("Người lớn (có tài khoản): ${fam['adults']}"),
                        Text("Trẻ em (<18 tuổi): ${fam['children']}"),
                      ],
                    ),
                    // NÚT XÓA HỘ GIA ĐÌNH
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                        size: 30,
                      ),
                      tooltip: 'Xóa hộ gia đình này',
                      onPressed: () => _deleteFamily(fam['family_id']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
