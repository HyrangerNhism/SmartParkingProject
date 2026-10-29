import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'api_service.dart';
import 'forgot_password_screen.dart'; // <-- Thêm import này

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(); // Biến mới cho SĐT
  final _familyCtrl = TextEditingController(text: "FAM01");
  DateTime? _selectedDate;
  String _accountType = 'Family';

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _register() async {
    if (_userCtrl.text.isEmpty ||
        _passCtrl.text.isEmpty ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đủ thông tin!")),
      );
      return;
    }

    String dobStr =
        "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";

    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userCtrl.text,
          "password": _passCtrl.text,
          "fullname": _nameCtrl.text,
          "dob": dobStr,
          "family_id": _familyCtrl.text,
          "account_type": _accountType,
          "phone": _phoneCtrl.text, // Gửi SĐT xuống server
        }),
      );
      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(data['message'])));
        if (data['success']) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Lỗi kết nối!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đăng ký Tài khoản Cư dân")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(labelText: "Tên đăng nhập"),
            ),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Mật khẩu"),
            ),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: "Họ và tên"),
            ),

            // Ô nhập Số điện thoại MỚI
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Số điện thoại (để khôi phục MK)",
              ),
            ),

            DropdownButtonFormField<String>(
              value: _accountType,
              decoration: const InputDecoration(labelText: "Loại tài khoản"),
              items: const [
                DropdownMenuItem(value: 'Family', child: Text('Hộ gia đình')),
                DropdownMenuItem(value: 'Single', child: Text('Độc thân')),
              ],
              onChanged: (v) => setState(() => _accountType = v!),
            ),

            TextField(
              controller: _familyCtrl,
              decoration: const InputDecoration(
                labelText: "Mã gia đình (VD: FAM01)",
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Text(
                  _selectedDate == null
                      ? "Chưa chọn ngày sinh"
                      : "Ngày sinh: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _pickDate,
                  child: const Text("Chọn ngày sinh"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _register,
              child: const Text("XÁC NHẬN ĐĂNG KÝ"),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                );
              },
              child: const Text("Đã có tài khoản? Quên mật khẩu?"),
            ),
          ],
        ),
      ),
    );
  }
}
