import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _userCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  bool _isOtpSent = false;

  void _sendOtp() async {
    if (_userCtrl.text.isEmpty || _phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập Username và SĐT!")),
      );
      return;
    }

    // Hiển thị trạng thái đang gửi
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Đang gửi mã OTP...")));

    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/send_otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userCtrl.text,
          "phone": _phoneCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);

      if (mounted) {
        if (data['success']) {
          setState(() => _isOtpSent = true);

          // Lấy mã OTP từ chuỗi thông báo của Server
          String fullMsg = data['message'] ?? "";
          String otpCode = fullMsg.contains("Mã test:")
              ? fullMsg.split("Mã test:")[1].trim()
              : "******";

          // HIỂN THỊ THÔNG BÁO GIỐNG TIN NHẮN ĐIỆN THOẠI
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(
                    Icons.message,
                    color: Colors.blue,
                    size: 35,
                  ), // Icon tin nhắn
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "TIN NHẮN MỚI (Smart Parking)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Mã OTP của bạn là: $otpCode. Vui lòng không chia sẻ mã này.",
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              duration: const Duration(
                seconds: 10,
              ), // Hiện 10 giây cho bạn kịp đọc
              behavior: SnackBarBehavior.floating, // Hiển thị nổi lên
              backgroundColor: Colors.white, // Nền trắng giống thông báo
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: const BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "Lỗi không xác định")),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Lỗi kết nối Server!")));
    }
  }

  void _resetPassword() async {
    if (_otpCtrl.text.isEmpty || _newPassCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập mã OTP và mật khẩu mới!")),
      );
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/reset_password'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userCtrl.text,
          "otp": _otpCtrl.text,
          "new_password": _newPassCtrl.text,
        }),
      );
      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(data['message'])));
        if (data['success'])
          Navigator.pop(context); // Quay về màn hình đăng nhập
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Lỗi kết nối Server!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quên Mật Khẩu")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: "Tên đăng nhập",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Số điện thoại đã đăng ký",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),

            if (!_isOtpSent)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _sendOtp,
                icon: const Icon(Icons.send),
                label: const Text("GỬI MÃ OTP"),
              )
            else ...[
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Nhập mã OTP (Xem thông báo tin nhắn)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Mật khẩu mới",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.green,
                ),
                onPressed: _resetPassword,
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  "XÁC NHẬN ĐỔI MẬT KHẨU",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
