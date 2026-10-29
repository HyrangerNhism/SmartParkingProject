import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:async'; // Bắt buộc phải có để dùng Timer

import 'api_service.dart';

import 'package:provider/provider.dart';

import 'auth_provider.dart';
import 'login_screen.dart';
import 'user_header.dart'; // <-- Import Header mới

import 'package:intl/intl.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  // --- BIẾN CHO TAB 1: KHAI BÁO KHÁCH ---
  String guestName = '';
  String vehicleType = 'None';
  String guestPlate = '';
  DateTime? selectedTimeIn;
  DateTime? selectedTimeOut;

  // --- BIẾN CHO TAB 2: QUẢN LÝ GIA ĐÌNH ---
  List<dynamic> familyMembers = [];
  bool isLoadingMembers = false;

  // --- BIẾN CHO TAB 3: THEO DÕI XE ---
  List<dynamic> myVehicles = [];
  bool isLoadingVehicles = false;

  // --- BIẾN CHO TAB 4: ĐĂNG KÝ XE ---
  final _newPlateCtrl = TextEditingController();
  final _newPhoneCtrl = TextEditingController();
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _fetchFamilyMembers();
    _fetchMyVehicles();
  }

  // ================= CÁC HÀM GỌI API =================

  void _fetchFamilyMembers() async {
    setState(() => isLoadingMembers = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/family_members/FAM01'),
      );
      if (res.statusCode == 200) {
        setState(() => familyMembers = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Lỗi: $e");
    }
    setState(() => isLoadingMembers = false);
  }

  void _fetchMyVehicles() async {
    setState(() => isLoadingVehicles = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/family/vehicles/FAM01'),
      );
      if (res.statusCode == 200) {
        setState(() => myVehicles = jsonDecode(res.body));
      }
    } catch (e) {
      debugPrint("Lỗi: $e");
    }
    setState(() => isLoadingVehicles = false);
  }

  void _registerVisitor() async {
    if (guestName.trim().isEmpty ||
        selectedTimeIn == null ||
        selectedTimeOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đủ tên và thời gian!")),
      );
      return;
    }
    String timeInStr = DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(selectedTimeIn!);
    String timeOutStr = DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(selectedTimeOut!);

    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/visitors'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "host_plate": "59A-123.45",
          "guest_name": guestName,
          "vehicle_type": vehicleType,
          "guest_plate": guestPlate,
          "time_in": timeInStr,
          "time_out": timeOutStr,
        }),
      );
      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Lỗi"),
            backgroundColor: data['success'] ? Colors.green : Colors.red,
          ),
        );
        if (data['success']) {
          setState(() {
            guestName = '';
            guestPlate = '';
            selectedTimeIn = null;
            selectedTimeOut = null;
            vehicleType = 'None';
          });
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Lỗi kết nối Server!")));
    }
  }

  void _showAddMemberDialog() {
    final nameCtrl = TextEditingController();
    DateTime? selectedDob;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Khai báo thành viên (<18 tuổi)"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Tên thành viên (VD: Bé C)",
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Text(
                      selectedDob == null
                          ? "Chưa chọn NS"
                          : "NS: ${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}",
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2015),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null)
                          setDialogState(() => selectedDob = picked);
                      },
                      child: const Text("Chọn ngày sinh"),
                    ),
                  ],
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
                  if (nameCtrl.text.isEmpty || selectedDob == null) return;
                  String dobStr = DateFormat('yyyy-MM-dd').format(selectedDob!);
                  try {
                    final res = await http.post(
                      Uri.parse('${ApiService.baseUrl}/family_members'),
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode({
                        "family_id": "FAM01",
                        "fullname": nameCtrl.text,
                        "dob": dobStr,
                      }),
                    );
                    final data = jsonDecode(res.body);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(data['message'])));
                      _fetchFamilyMembers();
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Lỗi kết nối!")),
                      );
                  }
                },
                child: const Text("Lưu"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _registerNewVehicle() async {
    if (_newPlateCtrl.text.isEmpty || _newPhoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập Biển số và SĐT!")),
      );
      return;
    }
    setState(() => _isRegistering = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/family/register_vehicle'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "plate": _newPlateCtrl.text.toUpperCase(),
          "owner": "Chủ hộ",
          "phone": _newPhoneCtrl.text,
          "family_id": "FAM01",
        }),
      );
      final data = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: data['success'] ? Colors.green : Colors.red,
          ),
        );
        if (data['success']) {
          _newPlateCtrl.clear();
          _newPhoneCtrl.clear();
          _fetchMyVehicles();
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Lỗi kết nối!")));
    }
    setState(() => _isRegistering = false);
  }

  // HÀM HIỂN THỊ HỘP THOẠI THANH TOÁN ONLINE (TỰ ĐỘNG XÁC NHẬN)
  void _showPaymentDialog(String plate) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        int timeLeft = 300; // 5 phút
        bool isExpired = false;
        bool isPaid = false;
        Map<String, dynamic>? receiptData;
        Timer? countdownTimer;
        Timer? autoPayTimer;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 1. Đồng hồ đếm ngược 5 phút
            countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (ctx.mounted && !isPaid) {
                if (timeLeft > 0) {
                  setDialogState(() => timeLeft--);
                } else {
                  setDialogState(() => isExpired = true);
                  t.cancel();
                }
              } else {
                t.cancel();
              }
            });

            // 2. GIẢ LẬP WEBHOOK: Tự động xác nhận sau 20 giây
            if (!isPaid && !isExpired) {
              autoPayTimer ??= Timer(const Duration(seconds: 20), () async {
                if (!ctx.mounted) return;

                try {
                  final res = await http.post(
                    Uri.parse('${ApiService.baseUrl}/payment/confirm'),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({"plate_number": plate}),
                  );
                  final data = jsonDecode(res.body);

                  if (data['success'] && ctx.mounted) {
                    countdownTimer?.cancel();
                    setDialogState(() {
                      isPaid = true;
                      receiptData = data['receipt'];
                    });
                    _fetchMyVehicles(); // Load lại danh sách để thấy hạn mới
                  }
                } catch (e) {
                  debugPrint("Lỗi tự động xác nhận: $e");
                }
              });
            }

            return AlertDialog(
              title: Text(
                isPaid ? "THANH TOÁN THÀNH CÔNG" : "Đang chờ thanh toán...",
              ),
              content: isPaid
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 60,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Biên lai thanh toán",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue,
                          ),
                        ),
                        const Divider(),
                        Text("Biển số: ${receiptData!['plate']}"),
                        Text("Nội dung: ${receiptData!['content']}"),
                        Text("Số tiền: ${receiptData!['amount']} VNĐ"),
                        Text("Thời gian: ${receiptData!['date']}"),
                        const Divider(),
                        const Text(
                          "Đã cộng 30 ngày vào thẻ!",
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isExpired
                              ? "Mã QR đã hết hạn!"
                              : "Mã QR (Hết hạn sau: ${timeLeft ~/ 60}:${(timeLeft % 60).toString().padLeft(2, '0')})",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isExpired
                                ? Colors.red
                                : (timeLeft < 60 ? Colors.red : Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Image.network(
                          'https://img.vietqr.io/image/VCB-1039339285-compact2.png?amount=30000&addInfo=GiaHan_$plate',
                          height: 200,
                          errorBuilder: (context, error, stackTrace) =>
                              const Text("Không tải được ảnh QR"),
                        ),
                        const SizedBox(height: 10),
                        const Text("Số tiền: 30.000 VNĐ"),
                        const Text("Nội dung: Gia hạn thẻ tháng"),
                        const SizedBox(height: 20),

                        if (!isExpired)
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                "Hệ thống đang chờ xác nhận chuyển khoản...",
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                      ],
                    ),
              actions: [
                if (!isPaid)
                  TextButton(
                    onPressed: () {
                      countdownTimer?.cancel();
                      autoPayTimer?.cancel();
                      Navigator.pop(ctx);
                    },
                    child: const Text("HỦY GIAO DỊCH"),
                  ),
                if (isPaid)
                  ElevatedButton(
                    onPressed: () {
                      countdownTimer?.cancel();
                      autoPayTimer?.cancel();
                      Navigator.pop(ctx);
                    },
                    child: const Text("ĐÓNG"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        // --- SỬ DỤNG USERHEADER KẾT HỢP TABBAR ---
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(130),
          child: Column(
            children: [
              UserHeader(
                username: auth.username, // Lấy tên đăng nhập
                role: 'Driver', // Truyền role Driver để hiện nút đổi Avatar
                onLogout: () {
                  Provider.of<AuthProvider>(context, listen: false).logout();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
              const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(icon: Icon(Icons.person_add), text: "Khai báo khách"),
                  Tab(icon: Icon(Icons.family_restroom), text: "Gia đình"),
                  Tab(icon: Icon(Icons.directions_car), text: "Theo dõi Xe"),
                  Tab(icon: Icon(Icons.add_circle), text: "Đăng ký Xe"),
                ],
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ================= TAB 1: KHAI BÁO KHÁCH =================
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "Khai báo khách đến chơi",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Tên khách",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => guestName = v,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: vehicleType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Phương tiện",
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'None',
                        child: Text('Đi bộ / Không xe'),
                      ),
                      DropdownMenuItem(
                        value: 'Motorbike',
                        child: Text('Xe máy'),
                      ),
                      DropdownMenuItem(value: 'Car', child: Text('Ô tô')),
                    ],
                    onChanged: (v) => setState(() => vehicleType = v!),
                  ),
                  if (vehicleType != 'None') ...[
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: "Biển số xe khách",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => guestPlate = v,
                    ),
                  ],

                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedTimeIn == null
                              ? "Chưa chọn giờ đến"
                              : "Đến: ${DateFormat('HH:mm - dd/MM/yyyy').format(selectedTimeIn!)}",
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          DateTime? date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                          );
                          if (date != null) {
                            TimeOfDay? time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null)
                              setState(
                                () => selectedTimeIn = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                ),
                              );
                          }
                        },
                        child: const Text("Chọn giờ đến"),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedTimeOut == null
                              ? "Chưa chọn giờ đi"
                              : "Đi: ${DateFormat('HH:mm - dd/MM/yyyy').format(selectedTimeOut!)}",
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          DateTime? date = await showDatePicker(
                            context: context,
                            initialDate: selectedTimeIn ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                          );
                          if (date != null) {
                            TimeOfDay? time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null)
                              setState(
                                () => selectedTimeOut = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                ),
                              );
                          }
                        },
                        child: const Text("Chọn giờ đi"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _registerVisitor,
                    child: const Text("GỬI KHAI BÁO ĐẾN BẢO VỆ"),
                  ),
                ],
              ),
            ),

            // ================= TAB 2: QUẢN LÝ GIA ĐÌNH =================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "Thông tin hộ gia đình",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Bạn có thể khai báo thông tin cho con cái dưới 18 tuổi tại đây.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: _showAddMemberDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text("Thêm thành viên (<18 tuổi)"),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const Text(
                    "Danh sách thành viên đã khai báo:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  isLoadingMembers
                      ? const Center(child: CircularProgressIndicator())
                      : familyMembers.isEmpty
                      ? const Text(
                          "Chưa có thành viên nào.",
                          style: TextStyle(color: Colors.grey),
                        )
                      : Expanded(
                          child: ListView.builder(
                            itemCount: familyMembers.length,
                            itemBuilder: (context, index) {
                              final member = familyMembers[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.child_care,
                                    color: Colors.pink,
                                    size: 30,
                                  ),
                                  title: Text(
                                    member['fullname'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text("Ngày sinh: ${member['dob']}"),
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),

            // ================= TAB 3: THEO DÕI XE & THẺ THÁNG =================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Danh sách xe của Hộ Gia đình",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Lưu ý: Để đăng ký/gia hạn thẻ tháng, bạn có thể tự thanh toán online hoặc liên hệ Bảo vệ.",
                    style: TextStyle(
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  isLoadingVehicles
                      ? const Center(child: CircularProgressIndicator())
                      : myVehicles.isEmpty
                      ? const Center(
                          child: Text(
                            "Hộ gia đình chưa đăng ký xe nào.\nHãy sang Tab 'Đăng ký Xe' để thêm.",
                          ),
                        )
                      : Expanded(
                          child: ListView.builder(
                            itemCount: myVehicles.length,
                            itemBuilder: (context, index) {
                              final vehicle = myVehicles[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ExpansionTile(
                                  leading: const Icon(
                                    Icons.directions_car,
                                    color: Colors.blue,
                                    size: 35,
                                  ),
                                  title: Text(
                                    vehicle['plate'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),

                                  // ĐÃ SỬA LOGIC TẠI ĐÂY: KIỂM TRA NGÀY HẾT HẠN
                                  subtitle: Builder(
                                    builder: (context) {
                                      DateTime expiryDate;
                                      try {
                                        expiryDate = DateFormat('dd/MM/yyyy')
                                            .parse(vehicle['expiry']);
                                      } catch (e) {
                                        expiryDate = DateTime(2000);
                                      }

                                      DateTime today = DateTime.now();
                                      bool isExpired = expiryDate.isBefore(
                                        DateTime(
                                          today.year,
                                          today.month,
                                          today.day,
                                        ),
                                      );

                                      return Text(
                                        isExpired
                                            ? "Hạn thẻ: ${vehicle['expiry']} (Đã hết hạn)"
                                            : "Hạn thẻ: ${vehicle['expiry']}",
                                        style: TextStyle(
                                          color: isExpired
                                              ? Colors.red
                                              : Colors.blue,
                                          fontWeight: isExpired
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      );
                                    },
                                  ),

                                  children: [
                                    // Trạng thái xe
                                    FutureBuilder(
                                      future: http.get(
                                        Uri.parse(
                                          '${ApiService.baseUrl}/family/vehicle_status/${vehicle['plate']}',
                                        ),
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          );
                                        }
                                        if (!snapshot.hasData)
                                          return const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: Text(
                                              "Không lấy được trạng thái",
                                            ),
                                          );

                                        final statusData = jsonDecode(
                                          snapshot.data!.body,
                                        );

                                        if (statusData['status'] == 'IN') {
                                          return ListTile(
                                            leading: const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            ),
                                            title: const Text(
                                              "Đang đỗ trong bãi",
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Giờ vào: ${statusData['time']}",
                                            ),
                                          );
                                        } else if (statusData['status'] ==
                                            'OUT') {
                                          return ListTile(
                                            leading: const Icon(
                                              Icons.exit_to_app,
                                              color: Colors.orange,
                                            ),
                                            title: const Text(
                                              "Đã rời khỏi bãi",
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text(
                                              "Giờ ra gần nhất: ${statusData['time']}",
                                            ),
                                          );
                                        } else {
                                          return const ListTile(
                                            leading: Icon(
                                              Icons.info,
                                              color: Colors.grey,
                                            ),
                                            title: Text(
                                              "Chưa có dữ liệu ra/vào",
                                            ),
                                          );
                                        }
                                      },
                                    ),

                                    // Nút Thanh toán Online
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size.fromHeight(
                                            45,
                                          ),
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.payment),
                                        label: const Text(
                                          "Gia hạn Online (30.000đ)",
                                        ),
                                        onPressed: () => _showPaymentDialog(
                                          vehicle['plate'],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),

            // ================= TAB 4: ĐĂNG KÝ XE =================
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    "Đăng ký Xe vào Hộ Gia đình",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Lưu ý: Sau khi thêm xe, bạn hãy ra Bảo vệ đóng phí 30.000đ để kích hoạt Thẻ tháng.",
                    style: TextStyle(
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _newPlateCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "Biển số xe",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _newPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "Số điện thoại",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _isRegistering
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _registerNewVehicle,
                          icon: const Icon(Icons.add),
                          label: const Text(
                            "THÊM XE VÀO HỘ",
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
