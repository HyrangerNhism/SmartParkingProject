from flask import Flask, render_template_string, jsonify, request
import database
from datetime import datetime
from flask_cors import CORS
import random
import string

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # Cho phép gửi dữ liệu lên tới 16MB
CORS(app)
# Lưu trữ mã OTP tạm thời trên RAM
otp_storage = {}

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <title>S-Parking | Director Dashboard</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        body { background-color: #f8f9fa; font-family: 'Segoe UI', system-ui, sans-serif; }
        .navbar { background: linear-gradient(90deg, #1A222C 0%, #2C3E50 100%); }
        .stat-card { border-radius: 15px; border: none; transition: transform 0.2s; color: white; overflow: hidden; position: relative;}
        .stat-card:hover { transform: translateY(-5px); box-shadow: 0 10px 20px rgba(0,0,0,0.1); }
        .stat-icon { position: absolute; right: 20px; top: 20px; font-size: 3rem; opacity: 0.3; }
        .bg-blue { background: linear-gradient(45deg, #4e73df, #224abe); }
        .bg-green { background: linear-gradient(45deg, #1cc88a, #13855c); }
        .bg-orange { background: linear-gradient(45deg, #f6c23e, #dda20a); }
        .table-custom { background: white; border-radius: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
        .blinking { animation: blinker 1.5s linear infinite; }
        @keyframes blinker { 50% { opacity: 0; } }
    </style>
</head>
<body>
    <nav class="navbar navbar-dark mb-4 shadow-sm py-3">
        <div class="container-fluid px-4">
            <a class="navbar-brand fw-bold fs-4" href="#">
                <i class="fa-solid fa-shield-halved text-info me-2"></i>S-PARKING CLOUD DASHBOARD
            </a>
            <div class="text-light">
                <i class="fa-solid fa-satellite-dish text-success blinking me-1"></i> Trực tiếp: <strong id="time_now">{{ time_now }}</strong>
            </div>
        </div>
    </nav>

    <div class="container-fluid px-4">
        <div class="row mb-4">
            <div class="col-xl-4 col-md-6 mb-4">
                <div class="card stat-card bg-blue shadow py-2">
                    <div class="card-body px-4">
                        <div class="text-uppercase fw-bold text-light mb-1">Tổng Lượt Vào (Hôm nay)</div>
                        <div class="fs-1 fw-bold"><span id="in_count">{{ in_count }}</span> <span class="fs-5 fw-normal">Lượt</span></div>
                        <i class="fa-solid fa-car-side stat-icon"></i>
                    </div>
                </div>
            </div>
            <div class="col-xl-4 col-md-6 mb-4">
                <div class="card stat-card bg-green shadow py-2">
                    <div class="card-body px-4">
                        <div class="text-uppercase fw-bold text-light mb-1">Doanh Thu Dự Kiến (VNĐ)</div>
                        <div class="fs-1 fw-bold"><span id="revenue">{{ "{:,}".format(revenue) }}</span> <span class="fs-5 fw-normal">đ</span></div>
                        <i class="fa-solid fa-wallet stat-icon"></i>
                    </div>
                </div>
            </div>
            <div class="col-xl-4 col-md-6 mb-4">
                <div class="card stat-card bg-orange shadow py-2">
                    <div class="card-body px-4">
                        <div class="text-uppercase fw-bold text-light mb-1">Trạng Thái Bãi Xe</div>
                        <div class="fs-1 fw-bold"><span id="parked_count">{{ parked_cars | length }} / {{ max_slots }}</span> <span class="fs-5 fw-normal">Xe đang đỗ</span></div>
                        <i class="fa-solid fa-square-parking stat-icon"></i>
                    </div>
                </div>
            </div>
        </div>

        <div class="card table-custom p-4">
            <div class="d-flex justify-content-between align-items-center mb-4">
                <h5 class="fw-bold text-secondary m-0"><i class="fa-solid fa-list-ul me-2"></i>DANH SÁCH XE TRONG BÃI THEO THỜI GIAN THỰC</h5>
                <span class="badge bg-primary rounded-pill px-3 py-2"><i class="fa-solid fa-circle-check"></i> Live Stream Data</span>
            </div>
            
            <div class="table-responsive">
                <table class="table table-hover align-middle">
                    <thead class="table-light text-secondary">
                        <tr>
                            <th scope="col">#</th>
                            <th scope="col">BIỂN SỐ XE</th>
                            <th scope="col">GIỜ VÀO BÃI</th>
                            <th scope="col">TRẠNG THÁI</th>
                        </tr>
                    </thead>
                    <tbody id="table_body">
                        {% for car in parked_cars %}
                        <tr>
                            <td><strong>{{ loop.index }}</strong></td>
                            <td><span class="badge border border-secondary text-dark fs-6 bg-light py-2 px-3">{{ car[0] }}</span></td>
                            <td class="text-muted fw-semibold"><i class="fa-regular fa-calendar me-1"></i> {{ car[1].strftime('%H:%M:%S | %d/%m/%Y') }}</td>
                            <td><span class="badge bg-success bg-opacity-10 text-success border border-success px-3 py-2 rounded-pill"><i class="fa-solid fa-circle text-success" style="font-size: 8px;"></i> Đang đỗ an toàn</span></td>
                        </tr>
                        {% else %}
                        <tr><td colspan="4" class="text-center text-muted py-5"><h5>Bãi xe hiện đang trống!</h5></td></tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        function formatNumber(num) {
            return num.toString().replace(/(\d)(?=(\d{3})+(?!\d))/g, '$1,');
        }

        function fetchLiveData() {
            fetch('/api/data')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('in_count').innerText = data.in_count;
                    document.getElementById('revenue').innerText = formatNumber(data.revenue);
                    document.getElementById('parked_count').innerText = data.parked_count + " / " + data.max_slots;
                    document.getElementById('time_now').innerText = data.time_now;

                    let tbody = document.getElementById('table_body');
                    tbody.innerHTML = '';
                    if (data.parked_cars.length === 0) {
                        tbody.innerHTML = '<tr><td colspan="4" class="text-center text-muted py-5"><h5>Bãi xe hiện đang trống!</h5></td></tr>';
                    } else {
                        data.parked_cars.forEach((car, index) => {
                            let row = `<tr>
                                <td><strong>${index + 1}</strong></td>
                                <td><span class="badge border border-secondary text-dark fs-6 bg-light py-2 px-3">${car.plate}</span></td>
                                <td class="text-muted fw-semibold"><i class="fa-regular fa-calendar me-1"></i> ${car.time_in}</td>
                                <td><span class="badge bg-success bg-opacity-10 text-success border border-success px-3 py-2 rounded-pill"><i class="fa-solid fa-circle text-success" style="font-size: 8px;"></i> Đang đỗ an toàn</span></td>
                            </tr>`;
                            tbody.innerHTML += row;
                        });
                    }
                })
                .catch(error => console.error("Lỗi cập nhật dữ liệu:", error));
        }
        setInterval(fetchLiveData, 2000);
    </script>
</body>
</html>
"""

@app.route('/')
def dashboard():
    database.init_db() 
    in_count, _, revenue = database.get_today_stats()
    parked_cars = database.get_parked_cars()
    time_now = datetime.now().strftime("%H:%M:%S")
    max_slots = database.MAX_SLOTS 
    return render_template_string(HTML_TEMPLATE, in_count=in_count, revenue=revenue, parked_cars=parked_cars, time_now=time_now, max_slots=max_slots)

@app.route('/api/data')
def api_data():
    database.init_db()
    in_count, _, revenue = database.get_today_stats()
    parked_cars_raw = database.get_parked_cars()
    time_now = datetime.now().strftime("%H:%M:%S")
    parked_cars = [{"plate": car[0], "time_in": car[1].strftime('%H:%M:%S | %d/%m/%Y')} for car in parked_cars_raw]
    return jsonify({
        "in_count": in_count, "revenue": revenue, "parked_cars": parked_cars,
        "parked_count": len(parked_cars), "max_slots": database.MAX_SLOTS, "time_now": time_now
    })

@app.route('/api/login', methods=['POST'])
def api_login():
    data = request.json
    role, msg = database.authenticate_user(data.get('username'), data.get('password'))
    if role:
        return jsonify({"success": True, "username": data.get('username'), "role": role})
    return jsonify({"success": False, "message": msg})

@app.route('/api/register', methods=['POST'])
def api_register():
    data = request.json
    success, msg = database.register_new_driver(
        username=data['username'],
        password=data['password'],
        fullname=data['fullname'],
        dob=data['dob'],
        family_id=data['family_id'],
        account_type=data.get('account_type', 'Family'),
        phone=data.get('phone') 
    )
    return jsonify({"success": success, "message": msg})

@app.route('/api/auth/send_otp', methods=['POST'])
def api_send_otp():
    data = request.json
    username = data.get('username')
    
    phone = database.get_user_phone(username)
    if not phone:
        phone = data.get('phone')
        database.update_phone(username, phone)
    
    if not phone:
        return jsonify({"success": False, "message": "Không tìm thấy SĐT của tài khoản này!"})
        
    otp = str(random.randint(100000, 999999))
    otp_storage[username] = otp
    
    print(f"--- [SMS GIẢ LẬP] Gửi đến số {phone}: Mã OTP của bạn là {otp} ---")
    return jsonify({"success": True, "message": f"Mã OTP đã được gửi đến số {phone} (Mã test: {otp})"})

@app.route('/api/auth/reset_password', methods=['POST'])
def api_reset_password():
    data = request.json
    username = data.get('username')
    otp_input = data.get('otp')
    new_password = data.get('new_password')
    
    if otp_storage.get(username) == otp_input:
        success, msg = database.update_password(username, new_password)
        if success: del otp_storage[username] 
        return jsonify({"success": success, "message": msg})
    else:
        return jsonify({"success": False, "message": "Mã OTP không đúng hoặc đã hết hạn!"})

# ================== API MỚI: QUẢN LÝ BẢO VỆ (ADMIN) ==================
@app.route('/api/admin/guards', methods=['GET'])
def get_all_guards():
    conn = database.get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT username, FullName, PhoneNumber FROM Users WHERE role = 'Guard'")
    rows = cursor.fetchall()
    conn.close()
    return jsonify([{"username": r[0], "fullname": r[1], "phone": r[2]} for r in rows])

@app.route('/api/admin/add_guard', methods=['POST'])
def add_guard():
    data = request.json
    conn = database.get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO Users (username, password, role, FullName, PhoneNumber) 
            VALUES (?, ?, 'Guard', ?, ?)
        """, (data['username'], data['password'], data['fullname'], data['phone']))
        conn.commit()
        return jsonify({"success": True, "message": "Thêm Bảo vệ thành công!"})
    except Exception as e:
        return jsonify({"success": False, "message": "Tên đăng nhập đã tồn tại!"})
    finally: conn.close()

@app.route('/api/admin/delete_guard/<username>', methods=['DELETE'])
def delete_guard(username):
    conn = database.get_connection()
    cursor = conn.cursor()
    cursor.execute("DELETE FROM Users WHERE username = ? AND role = 'Guard'", (username,))
    conn.commit()
    conn.close()
    return jsonify({"success": True, "message": "Đã xóa Bảo vệ!"})

# (Các API blacklist, monthly_cards, visitors, family, payment... giữ nguyên y như file cũ)
@app.route('/api/blacklist', methods=['GET'])
def api_get_blacklist():
    conn = database.get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT plate_number, reason, AddedBy FROM Blacklist")
    rows = cursor.fetchall()
    conn.close()
    result = [{"plate": r[0], "reason": r[1], "added_by": r[2] if r[2] else "Admin"} for r in rows]
    return jsonify(result)

@app.route('/api/blacklist', methods=['POST'])
def api_add_blacklist():
    data = request.json
    success, msg = database.add_blacklist(
        data.get('plate', '').upper(), data.get('reason', ''), data.get('added_by', 'Admin')
    )
    return jsonify({"success": success, "message": msg})

@app.route('/api/blacklist/<plate>', methods=['DELETE'])
def api_delete_blacklist(plate):
    conn = database.get_connection()
    if not conn: return jsonify({"success": False, "message": "Lỗi CSDL"}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM Blacklist WHERE plate_number = ?", (plate,))
        conn.commit()
        return jsonify({"success": True, "message": f"Đã xóa xe {plate} khỏi Sổ Đen."})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        conn.close()

@app.route('/api/monthly_cards', methods=['GET'])
def api_get_monthly_cards():
    conn = database.get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT m.plate_number, m.owner_name, m.phone_number, m.expiry_date, m.FamilyId, u.AccountType
        FROM MonthlyCards m
        LEFT JOIN Users u ON m.FamilyId = u.FamilyId
        WHERE m.is_active=1
    """)
    rows = cursor.fetchall()
    conn.close()
    result = []
    for r in rows:
        owner_display = r[1]
        if r[5] == 'Single':
            owner_display = f"Anh/Chị {r[1]}"
        elif r[4]:
            owner_display = f"Hộ GĐ {r[4]}"

        result.append({
            "plate": r[0], "owner": owner_display, "phone": r[2],
            "expiry": r[3].strftime("%d/%m/%Y") if r[3] else "N/A"
        })
    return jsonify(result)

@app.route('/api/monthly_cards/<plate>', methods=['DELETE'])
def api_delete_monthly_card(plate):
    success, msg = database.delete_monthly_card(plate)
    return jsonify({"success": success, "message": msg})

@app.route('/api/register_monthly_card', methods=['POST'])
def api_register_monthly_card():
    data = request.json
    success, msg = database.register_monthly_card(
        plate_number=data['plate_number'].upper(),
        owner_name=data['owner_name'],
        phone=data['phone'],
        family_id=data.get('family_id')
    )
    return jsonify({"success": success, "message": msg})

@app.route('/api/visitors/check/<plate>', methods=['GET'])
def api_check_visitor(plate):
    result = database.check_guest_by_plate(plate.upper())
    return jsonify(result)

@app.route('/api/visitors', methods=['POST'])
def api_register_visitor():
    data = request.json
    try:
        success, msg = database.register_visitor(
            host_plate=data['host_plate'].upper(), guest_name=data['guest_name'],
            vehicle_type=data['vehicle_type'],
            guest_plate=data.get('guest_plate', '').upper() if data['vehicle_type'] != 'None' else None,
            time_in=data['time_in'], time_out=data.get('time_out')
        )
        return jsonify({"success": success, "message": msg})
    except Exception as e: return jsonify({"success": False, "message": str(e)}), 500

@app.route('/api/visitors/today', methods=['GET'])
def api_get_visitors_today():
    conn = database.get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT GuestName, GuestPlate, HostPlate, ExpectedTimeIn, ExpectedTimeOut, Status 
        FROM Visitors 
        WHERE Status IN ('Pending', 'CheckedIn')
        ORDER BY ExpectedTimeIn DESC
    """)
    rows = cursor.fetchall()
    conn.close()

    result = []
    now = datetime.now()
    for r in rows:
        status = r[5]
        expected_out = r[4]
        
        if status == 'CheckedIn':
            if expected_out and now > expected_out:
                status = 'Đã quá hạn'
            else:
                status = 'Đang ở (Trong hạn)'
        elif status == 'Pending':
            status = 'Chờ đến'
            
        result.append({
            "guest_name": r[0], 
            "guest_plate": r[1] if r[1] else "Đi bộ", 
            "host_plate": r[2], 
            "time_in": r[3].strftime("%H:%M %d/%m") if r[3] else "", 
            "status": status
        })
    return jsonify(result)

@app.route('/api/visitors/all', methods=['GET'])
def api_get_all_visitors():
    conn = database.get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT VisitorId, GuestName, GuestPlate, HostPlate FROM Visitors ORDER BY ExpectedTimeIn DESC")
    rows = cursor.fetchall()
    conn.close()
    return jsonify([{"id": r[0], "guest_name": r[1], "guest_plate": r[2], "host_plate": r[3]} for r in rows])

@app.route('/api/visitors/<int:visitor_id>', methods=['DELETE'])
def api_delete_visitor(visitor_id):
    conn = database.get_connection()
    if not conn: return jsonify({"success": False, "message": "Lỗi CSDL"}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM Visitors WHERE VisitorId = ?", (visitor_id,))
        conn.commit()
        return jsonify({"success": True, "message": "Đã hủy đơn khách thành công."})
    except Exception as e: return jsonify({"success": False, "message": str(e)}), 500
    finally: conn.close()

@app.route('/api/visitors/history/<host_plate>', methods=['GET'])
def api_visitor_history(host_plate):
    return jsonify(database.get_visitor_history(host_plate))

@app.route('/api/family_members', methods=['POST'])
def api_add_family_member():
    data = request.json
    success, msg = database.add_family_member(
        family_id=data['family_id'], fullname=data['fullname'], dob=data['dob']
    )
    return jsonify({"success": success, "message": msg})

@app.route('/api/family_members/<family_id>', methods=['GET'])
def api_get_family_members(family_id):
    conn = database.get_connection()
    if not conn: return jsonify([])
    cursor = conn.cursor()
    cursor.execute("SELECT MemberId, FullName, DateOfBirth FROM FamilyMembers WHERE FamilyId = ?", (family_id,))
    rows = cursor.fetchall()
    conn.close()
    
    result = []
    for r in rows:
        result.append({
            "id": r[0],
            "fullname": r[1],
            "dob": r[2].strftime("%d/%m/%Y") if r[2] else ""
        })
    return jsonify(result)

@app.route('/api/admin/users', methods=['GET'])
def api_get_all_users():
    conn = database.get_connection()
    if not conn: return jsonify([])
    cursor = conn.cursor()
    cursor.execute("SELECT username, role, FullName, FamilyId, AccountType FROM Users")
    rows = cursor.fetchall()
    conn.close()
    result = []
    for r in rows:
        result.append({
            "username": r[0], "role": r[1], "fullname": r[2] if r[2] else "Chưa cập nhật",
            "family_id": r[3] if r[3] else "N/A", "account_type": "Độc thân" if r[4] == 'Single' else "Gia đình"
        })
    return jsonify(result)

@app.route('/api/admin/families', methods=['GET'])
def api_get_all_families():
    conn = database.get_connection()
    if not conn: return jsonify([])
    cursor = conn.cursor()
    cursor.execute("SELECT DISTINCT FamilyId FROM Users WHERE FamilyId IS NOT NULL AND FamilyId != ''")
    families = cursor.fetchall()
    
    result = []
    for fam in families:
        family_id = fam[0]
        cursor.execute("SELECT COUNT(*) FROM Users WHERE FamilyId = ?", (family_id,))
        adults_count = cursor.fetchone()[0] or 0
        cursor.execute("SELECT COUNT(*) FROM FamilyMembers WHERE FamilyId = ?", (family_id,))
        children_count = cursor.fetchone()[0] or 0
        result.append({
            "family_id": family_id, "adults": adults_count,
            "children": children_count, "total_members": adults_count + children_count
        })
    conn.close()
    return jsonify(result)

@app.route('/api/admin/families/<family_id>', methods=['DELETE'])
def api_delete_family(family_id):
    conn = database.get_connection()
    if not conn: return jsonify({"success": False, "message": "Lỗi CSDL"}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM Visitors WHERE HostPlate IN (SELECT PlateNumber FROM MonthlyCards WHERE FamilyId = ?)", (family_id,))
        cursor.execute("DELETE FROM MonthlyFaces WHERE plate_number IN (SELECT plate_number FROM MonthlyCards WHERE FamilyId = ?)", (family_id,))
        cursor.execute("DELETE FROM MonthlyCards WHERE FamilyId = ?", (family_id,))
        cursor.execute("DELETE FROM FamilyMembers WHERE FamilyId = ?", (family_id,))
        cursor.execute("DELETE FROM Users WHERE FamilyId = ?", (family_id,))
        conn.commit()
        return jsonify({"success": True, "message": f"Đã xóa toàn bộ dữ liệu của hộ {family_id} thành công."})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        conn.close()

@app.route('/api/guard/register_monthly_card', methods=['POST'])
def api_guard_register_card():
    data = request.json
    success, msg = database.register_monthly_card(
        plate_number=data['plate_number'].upper(), owner_name=data['owner_name'],
        phone=data['phone'], family_id=data.get('family_id')
    )
    return jsonify({"success": success, "message": msg})

@app.route('/api/guard/register_family_cards', methods=['POST'])
def api_guard_register_family_cards():
    data = request.json
    family_id = data.get('family_id')
    conn = database.get_connection()
    if not conn: return jsonify({"success": False, "message": "Lỗi CSDL"}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT plate_number FROM MonthlyCards WHERE FamilyId = ?", (family_id,))
        vehicles = cursor.fetchall()
        if not vehicles:
            return jsonify({"success": False, "message": f"Hộ {family_id} chưa đăng ký xe nào trong hệ thống!"})
        for v in vehicles:
            cursor.execute("""
                UPDATE MonthlyCards 
                SET expiry_date = DATEADD(day, 30, GETDATE()), start_date = GETDATE()
                WHERE plate_number = ?
            """, (v[0],))
        conn.commit()
        return jsonify({"success": True, "message": f"Đã gia hạn 30 ngày thành công cho {len(vehicles)} xe của hộ {family_id}."})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        conn.close()

@app.route('/api/family/vehicles/<family_id>', methods=['GET'])
def api_get_family_vehicles(family_id):
    conn = database.get_connection()
    if not conn: return jsonify([])
    cursor = conn.cursor()
    cursor.execute("SELECT plate_number, expiry_date FROM MonthlyCards WHERE FamilyId = ? AND is_active = 1", (family_id,))
    rows = cursor.fetchall()
    conn.close()
    return jsonify([{"plate": r[0], "expiry": r[1].strftime("%d/%m/%Y") if r[1] else "N/A"} for r in rows])

@app.route('/api/family/vehicle_status/<plate>', methods=['GET'])
def api_get_vehicle_status(plate):
    conn = database.get_connection()
    if not conn: return jsonify({"status": "Unknown"})
    cursor = conn.cursor()
    
    cursor.execute("SELECT time_in FROM ParkingRecords WHERE plate_number = ? AND status = 'IN'", (plate,))
    current_in = cursor.fetchone()
    if current_in:
        conn.close()
        return jsonify({"status": "IN", "time": current_in[0].strftime("%H:%M - %d/%m/%Y")})
        
    cursor.execute("SELECT time_out FROM ParkingRecords WHERE plate_number = ? AND status = 'OUT' ORDER BY time_out DESC", (plate,))
    last_out = cursor.fetchone()
    conn.close()
    if last_out:
        return jsonify({"status": "OUT", "time": last_out[0].strftime("%H:%M - %d/%m/%Y")})
    return jsonify({"status": "NOT_FOUND", "time": ""})

@app.route('/api/family/register_vehicle', methods=['POST'])
def api_family_register_vehicle():
    data = request.json
    conn = database.get_connection()
    if not conn: return jsonify({"success": False, "message": "Lỗi CSDL"}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT plate_number FROM MonthlyCards WHERE plate_number = ?", (data['plate'],))
        if cursor.fetchone():
            return jsonify({"success": False, "message": "Biển số xe này đã được đăng ký trong hệ thống!"})
        cursor.execute("""
            INSERT INTO MonthlyCards (plate_number, owner_name, phone_number, start_date, expiry_date, is_active, FamilyId)
            VALUES (?, ?, ?, GETDATE(), DATEADD(day, 0, GETDATE()), 1, ?)
        """, (data['plate'].upper(), data['owner'], data['phone'], data['family_id']))
        conn.commit()
        return jsonify({"success": True, "message": f"Đã thêm xe {data['plate'].upper()} vào hộ gia đình. Vui lòng ra Bảo vệ để đóng phí gia hạn thẻ!"})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        conn.close()

@app.route('/api/payment/create_code', methods=['POST'])
def api_create_payment():
    data = request.json
    plate = data.get('plate_number').upper()
    code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    return jsonify({
        "success": True, 
        "payment_code": code, 
        "amount": 30000,
        "expires_in": 300 
    })

@app.route('/api/payment/confirm', methods=['POST'])
def api_confirm_payment():
    data = request.json
    plate = data.get('plate_number').upper()
    
    success, msg = database.renew_single_card(plate)
    
    if success:
        return jsonify({
            "success": True, 
            "message": "Thanh toán thành công",
            "receipt": {
                "plate": plate,
                "amount": 30000,
                "date": datetime.now().strftime("%d/%m/%Y %H:%M:%S"),
                "content": "Gia hạn thẻ tháng 30 ngày"
            }
        })
    return jsonify({"success": False, "message": msg})

# ================== API QUẢN LÝ AVATAR ==================
@app.route('/user/avatar/<username>', methods=['GET'])
def get_avatar(username):
    conn = database.get_connection()
    if not conn: return jsonify({"avatar_url": ""})
    cursor = conn.cursor()
    cursor.execute("SELECT AvatarUrl FROM Users WHERE username = ?", (username,))
    row = cursor.fetchone()
    conn.close()
    return jsonify({"avatar_url": row[0] if row and row[0] else ""})

@app.route('/user/update_avatar', methods=['POST'])
def update_avatar():
    data = request.json
    conn = database.get_connection()
    if not conn: return jsonify({"success": False, "message": "Lỗi CSDL"}), 500
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE Users SET AvatarUrl = ? WHERE username = ?", (data['avatar_url'], data['username']))
        conn.commit()
        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "message": str(e)}), 500
    finally:
        conn.close()

if __name__ == '__main__':
    print("==================================================")
    print("🚀 Khởi động MICROSERVICE (Web Admin & Flutter API) 🚀")
    print("👉 Mở trình duyệt và truy cập: http://127.0.0.1:5000")
    print("==================================================")
    app.run(host='0.0.0.0', port=5000, debug=False)