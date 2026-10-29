import 'package:flutter/material.dart';

class UserHeader extends StatelessWidget {
  final String username;
  final String role;
  final VoidCallback onLogout;

  const UserHeader({
    super.key,
    required this.username,
    required this.role,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    // Lấy chữ cái đầu tiên của tên đăng nhập
    String initialLetter = username.isNotEmpty
        ? username[0].toUpperCase()
        : "?";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade800,
      child: Row(
        children: [
          // Avatar hình tròn hiển thị chữ cái
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            child: Text(
              initialLetter,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Tên đăng nhập
          Expanded(
            child: Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Nút Đăng xuất
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
