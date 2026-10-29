import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_service.dart';

import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'login_screen.dart';
import 'blacklist_screen.dart';

class GuardDashboard extends StatefulWidget {
  const GuardDashboard({super.key});

  @override
  State<GuardDashboard> createState() => _GuardDashboardState();
}

class _GuardDashboardState extends State<GuardDashboard> {
  final _plateCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();

  // Hàm kiểm tra khách (Giả lập AI quét)
  void _checkGuest() async {
    if (_plateCtrl.text.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/visitors/check/${_plateCtrl.text}'),
      );
      final data = jsonDecode(res.body);

      if (data['is_registered']) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
            title: const Text(
              "KHÁCH HỢP LỆ",
              style: TextStyle(color: Colors.green),
              textAlign: TextAlign.center,
            ),
            content: Text(
              "Biển số: ${_plateCtrl.text.toUpperCase()}\n\nKhách của: ${data['host_name']} (Căn hộ ${data['host_plate']})\n\nDự kiến về: ${data['expected_out']}",
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  _plateCtrl.clear();
                  Navigator.pop(ctx);
                },
                child: const Text("MỞ BARRIER & ĐÓNG"),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.warning, color: Colors.red, size: 50),
            title: const Text(
              "CẢNH BÁO: XE LẠ!",
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            content: const Text(
              "Biển số này KHÔNG CÓ trong danh sách khai báo trước. Vui lòng liên hệ chủ nhà để xác minh!",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("ĐÓNG"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Lỗi kết nối Server!")));
    }
  }

  // Hàm Gia hạn cả hộ
  void _renewFamily() async {
    if (_familyCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Vui lòng nhập Mã Hộ!")));
      return;
    }
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/guard/register_family_cards'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"family_id": _familyCtrl.text.toUpperCase()}),
      );
      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: data['success'] ? Colors.green : Colors.red,
          ),
        );
        if (data['success']) _familyCtrl.clear();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Lỗi kết nối!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Trạm kiểm soát - Bảo Vệ"),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.directions_car), text: "Kiểm tra khách"),
              Tab(icon: Icon(Icons.list_alt), text: "Khách hôm nay"),
              Tab(icon: Icon(Icons.block), text: "Quản lý Sổ Đen"),
              Tab(icon: Icon(Icons.add_card), text: "Cấp thẻ tháng"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // ================= TAB 1: KIỂM TRA KHÁCH =================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "Giả lập AI quét biển số khách",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _plateCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "Nhập biển số xe khách...",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.camera_alt),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _checkGuest,
                    icon: const Icon(Icons.search),
                    label: const Text(
                      "KIỂM TRA BIỂN SỐ",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            // ================= TAB 2: DANH SÁCH KHÁCH HÔM NAY =================
            FutureBuilder(
              future: http.get(
                Uri.parse('${ApiService.baseUrl}/visitors/today'),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.body == '[]') {
                  return const Center(
                    child: Text("Hôm nay chưa có khách đăng ký."),
                  );
                }
                final visitors = jsonDecode(
                  utf8.decode(snapshot.data!.bodyBytes),
                );
                return ListView.builder(
                  itemCount: visitors.length,
                  itemBuilder: (context, index) {
                    final v = visitors[index];

                    // Xác định màu sắc dựa vào trạng thái
                    Color chipColor;
                    Color textColor = Colors.black;
                    if (v['status'] == 'Đã quá hạn') {
                      chipColor = Colors.red.shade100;
                      textColor = Colors.red.shade900;
                    } else if (v['status'] == 'Đang ở (Trong hạn)') {
                      chipColor = Colors.green.shade100;
                      textColor = Colors.green.shade900;
                    } else {
                      chipColor = Colors.orange.shade100; // Chờ đến
                      textColor = Colors.orange.shade900;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: Text(
                          v['guest_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Biển số: ${v['guest_plate']}\nChủ nhà: ${v['host_plate']}\nGiờ đến: ${v['time_in']}",
                        ),
                        isThreeLine: true,
                        trailing: Chip(
                          label: Text(
                            v['status'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          backgroundColor: chipColor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // ================= TAB 3: SỔ ĐEN =================
            const BlacklistScreen(),

            // ================= TAB 4: CẤP THẺ THÁNG =================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "Gia hạn Thẻ tháng cho toàn bộ xe của Hộ",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Thu phí: 30.000đ/xe (Hệ thống tự động cộng 30 ngày cho tất cả xe)",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _familyCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "Nhập Mã Hộ Gia đình (VD: FAM01)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.house),
                    ),
                  ),
                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _renewFamily,
                    icon: const Icon(Icons.autorenew),
                    label: const Text(
                      "XÁC NHẬN THU TIỀN & GIA HẠN",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
