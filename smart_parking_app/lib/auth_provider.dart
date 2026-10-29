import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  String _role = '';
  String _username = '';

  String get role => _role;
  String get username => _username;

  void login(String user, String role) {
    _username = user;
    _role = role;
    notifyListeners();
  }

  void logout() {
    _username = '';
    _role = '';
    notifyListeners();
  }
}
