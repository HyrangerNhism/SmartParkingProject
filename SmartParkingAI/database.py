import pyodbc
from datetime import datetime, timedelta
import csv
import requests 
import json
import numpy as np

# --- CẤU HÌNH SQL SERVER ---
SERVER = r'DSY-LAPTOP\ANHTUANSQL' 
DATABASE = 'SmartParkingDB'
CONN_STR = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes;'
MAX_SLOTS = 120

# --- CẤU HÌNH TELEGRAM BOT ---
TELEGRAM_TOKEN = "8691485820:AAGK1WRsqcQNiJz4T4s-LbEWlCCFF-RMbbk" 
TELEGRAM_CHAT_ID = "8745764431"

def send_telegram_alert(message, image_path=None):
    try:
        if image_path:
            url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendPhoto"
            with open(image_path, 'rb') as photo:
                payload = {'chat_id': TELEGRAM_CHAT_ID, 'caption': message}
                requests.post(url, data=payload, files={'photo': photo})
        else:
            url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"
            payload = {'chat_id': TELEGRAM_CHAT_ID, 'text': message}
            requests.post(url, json=payload)
    except Exception as e:
        print(f"Lỗi gửi Telegram: {e}")

def get_connection():
    try:
        return pyodbc.connect(CONN_STR)
    except pyodbc.Error as e:
        print(f"Lỗi kết nối SQL Server: {e}")
        return None

def init_db():
    conn = get_connection()
    if conn:
        print("✅ Đã kết nối thành công tới SQL Server!")
        conn.close()
    else:
        print("❌ Kết nối SQL Server thất bại!")

def authenticate_user(username, password):
    conn = get_connection()
    if not conn: return None, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    cursor.execute("SELECT role FROM Users WHERE username=? AND password=?", (username, password))
    user = cursor.fetchone()
    conn.close()
    if user: return user[0], f"✅ Đăng nhập thành công! Quyền: {user[0]}"
    else: return None, "❌ Sai tài khoản hoặc mật khẩu!"

# ================== CÁC HÀM CHO QUÊN MẬT KHẨU ==================
def update_password(username, new_password):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE Users SET password = ? WHERE username = ?", (new_password, username))
        conn.commit()
        return True, "Đổi mật khẩu thành công!"
    except Exception as e:
        return False, f"Lỗi: {e}"
    finally: conn.close()

def update_phone(username, phone):
    conn = get_connection()
    if not conn: return False
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE Users SET PhoneNumber = ? WHERE username = ?", (phone, username))
        conn.commit()
        return True
    except: return False
    finally: conn.close()

def get_user_phone(username):
    conn = get_connection()
    if not conn: return None
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT PhoneNumber FROM Users WHERE username = ?", (username,))
        row = cursor.fetchone()
        return row[0] if row else None
    except: return None
    finally: conn.close()
# ===============================================================

def get_available_slots():
    conn = get_connection()
    if not conn: return MAX_SLOTS
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM ParkingRecords WHERE status='IN'")
    count = cursor.fetchone()[0]
    conn.close()
    return MAX_SLOTS - count

def is_car_in(plate_number):
    conn = get_connection()
    if not conn: return False
    cursor = conn.cursor()
    cursor.execute("SELECT id FROM ParkingRecords WHERE plate_number=? AND status='IN'", (plate_number,))
    record = cursor.fetchone()
    conn.close()
    return bool(record)

def check_in(plate_number):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    
    cursor.execute("SELECT reason FROM Blacklist WHERE plate_number=?", (plate_number,))
    blacklisted = cursor.fetchone()
    if blacklisted:
        conn.close()
        return False, f"🚨 BÁO ĐỘNG: TỪ CHỐI XE {plate_number}! Lý do: {blacklisted[0]}"

    slots_left = get_available_slots()
    if slots_left <= 0: return False, "🛑 TỪ CHỐI: Bãi xe đã đầy!"
    
    time_now_obj = datetime.now()
    time_now_str = time_now_obj.strftime("%Y-%m-%d %H:%M:%S")
    
    cursor.execute("SELECT * FROM ParkingRecords WHERE plate_number=? AND status='IN'", (plate_number,))
    if cursor.fetchone():
        conn.close()
        return False, f"⚠️ Cảnh báo: Xe {plate_number} đã nằm trong bãi rồi!"

    cursor.execute("SELECT owner_name, expiry_date FROM MonthlyCards WHERE plate_number=? AND is_active=1", (plate_number,))
    monthly_card = cursor.fetchone()
    
    guest_type_msg = "Khách vãng lai"
    if monthly_card:
        owner_name = monthly_card[0]
        expiry_date = monthly_card[1]
        if expiry_date >= time_now_obj.date(): guest_type_msg = f"Vé tháng VIP - Chào {owner_name}"
        else: guest_type_msg = f"⚠️ VÉ THÁNG ĐÃ HẾT HẠN!"
    else:
        cursor.execute("SELECT GuestName, HostPlate FROM Visitors WHERE GuestPlate = ? AND Status = 'Pending'", (plate_number,))
        visitor = cursor.fetchone()
        if visitor:
            guest_type_msg = f"Khách của hộ {visitor[1]} (Tên: {visitor[0]})"
            cursor.execute("UPDATE Visitors SET Status = 'CheckedIn' WHERE GuestPlate = ?", (plate_number,))
            conn.commit()

    cursor.execute("INSERT INTO ParkingRecords (plate_number, time_in, status, fee) VALUES (?, ?, 'IN', 0)", (plate_number, time_now_str))
    conn.commit()
    conn.close()
    return True, f"📥 [VÀO] Xe {plate_number} ({guest_type_msg}) | Trống: {slots_left - 1}/{MAX_SLOTS}"

def check_out(plate_number):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    
    cursor.execute("SELECT reason FROM Blacklist WHERE plate_number=?", (plate_number,))
    blacklisted = cursor.fetchone()
    if blacklisted:
        conn.close()
        return False, f"🚨 BÁO ĐỘNG: GIỮ XE {plate_number} LẠI NGAY! Lý do: {blacklisted[0]}"

    time_now_obj = datetime.now()
    time_now_str = time_now_obj.strftime("%Y-%m-%d %H:%M:%S")
    
    cursor.execute("SELECT id, time_in FROM ParkingRecords WHERE plate_number=? AND status='IN'", (plate_number,))
    record = cursor.fetchone()
    
    if record:
        record_id = record[0]
        time_in_obj = record[1] 
        duration_seconds = (time_now_obj - time_in_obj).total_seconds()
        
        cursor.execute("SELECT expiry_date FROM MonthlyCards WHERE plate_number=? AND is_active=1", (plate_number,))
        monthly_card = cursor.fetchone()
        
        fee = 0 
        if monthly_card and monthly_card[0] >= time_now_obj.date(): fee_msg = "MIỄN PHÍ (Vé Tháng)"
        else:
            fee = 2000 if duration_seconds <= 60 else 5000
            fee_msg = f"{fee:,} VNĐ"
            
        cursor.execute("UPDATE ParkingRecords SET time_out=?, status='OUT', fee=? WHERE id=?", (time_now_str, fee, record_id))
        conn.commit()
        conn.close()
        return True, f"📤 [RA] Xe {plate_number} | Đỗ: {int(duration_seconds)}s | THU TIỀN: {fee_msg}"
    else:
        conn.close()
        return False, f"❌ Lỗi: Không tìm thấy xe {plate_number} trong bãi!"

def register_monthly_card(plate_number, owner_name, phone, months=1, family_id=None):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    
    start_date = datetime.now().date()
    expiry_date = start_date + timedelta(days=30 * months) 
    
    try:
        cursor.execute("""
            INSERT INTO MonthlyCards (plate_number, owner_name, phone_number, start_date, expiry_date, is_active, FamilyId) 
            VALUES (?, ?, ?, ?, ?, 1, ?)
        """, (plate_number, owner_name, phone, start_date, expiry_date, family_id))
        conn.commit()
        return True, f"✅ Đã đăng ký vé tháng cho {plate_number} (Hết hạn: {expiry_date.strftime('%d/%m/%Y')})"
    except Exception as e: 
        return False, f"⚠️ Lỗi đăng ký vé tháng: {e}"
    finally: conn.close()

def delete_monthly_card(plate_number):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM MonthlyFaces WHERE plate_number=?", (plate_number,))
        cursor.execute("DELETE FROM MonthlyCards WHERE plate_number=?", (plate_number,))
        conn.commit()
        return True, f"🗑️ Đã hủy và xóa hoàn toàn hồ sơ vé tháng của xe {plate_number}!"
    except Exception as e:
        return False, f"❌ Lỗi hệ thống khi hủy vé: {e}"
    finally: conn.close()

def get_today_stats():
    conn = get_connection()
    cursor = conn.cursor()
    today_str = datetime.now().strftime("%Y-%m-%d")
    cursor.execute("SELECT COUNT(*) FROM ParkingRecords WHERE CAST(time_in AS DATE) = ?", (today_str,))
    in_count = cursor.fetchone()[0] or 0
    cursor.execute("SELECT COUNT(*) FROM ParkingRecords WHERE CAST(time_out AS DATE) = ?", (today_str,))
    out_count = cursor.fetchone()[0] or 0
    cursor.execute("SELECT SUM(fee) FROM ParkingRecords WHERE CAST(time_out AS DATE) = ?", (today_str,))
    rev = cursor.fetchone()[0] or 0
    conn.close()
    return in_count, out_count, rev

def get_parked_cars():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT plate_number, time_in FROM ParkingRecords WHERE status='IN' ORDER BY time_in DESC")
    cars = cursor.fetchall()
    conn.close()
    return cars

def export_today_csv():
    conn = get_connection()
    cursor = conn.cursor()
    today_str = datetime.now().strftime("%Y-%m-%d")
    cursor.execute("SELECT plate_number, time_in, time_out, status, fee FROM ParkingRecords WHERE CAST(time_in AS DATE) = ?", (today_str,))
    records = cursor.fetchall()
    conn.close()
    if not records: return False, "Hôm nay chưa có dữ liệu!"
    filename = f"BaoCao_DoanhThu_{today_str}.csv"
    try:
        with open(filename, mode='w', newline='', encoding='utf-8-sig') as file:
            writer = csv.writer(file)
            writer.writerow(["Biển số", "Giờ vào", "Giờ ra", "Trạng thái", "Phí thu (VNĐ)"])
            for r in records:
                t_out = r[2].strftime("%H:%M:%S") if r[2] else ""
                writer.writerow([r[0], r[1].strftime("%H:%M:%S"), t_out, r[3], r[4]])
        return True, f"✅ Đã lưu file Excel: {filename}"
    except Exception as e: return False, f"❌ Lỗi lưu file: {e}"

def export_last_30_days_csv():
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    start_date = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
    
    cursor.execute("SELECT plate_number, time_in, time_out, status, fee FROM ParkingRecords WHERE CAST(time_in AS DATE) >= ? ORDER BY time_in DESC", (start_date,))
    records = cursor.fetchall()
    conn.close()
    
    if not records: return False, "Không có dữ liệu trong 30 ngày qua!"
    
    filename = f"BaoCao_30Ngay_{datetime.now().strftime('%Y%m%d')}.csv"
    try:
        with open(filename, mode='w', newline='', encoding='utf-8-sig') as file:
            writer = csv.writer(file)
            writer.writerow(["Biển số", "Giờ vào", "Giờ ra", "Trạng thái", "Phí thu (VNĐ)"])
            in_count = 0
            out_count = 0
            total_fee = 0
            for r in records:
                t_out = r[2].strftime("%H:%M:%S %d/%m/%Y") if r[2] else "Chưa ra"
                writer.writerow([r[0], r[1].strftime("%H:%M:%S %d/%m/%Y"), t_out, r[3], r[4]])
                in_count += 1
                if r[3] == 'OUT':
                    out_count += 1
                    total_fee += r[4] if r[4] else 0
            writer.writerow([])
            writer.writerow(["=== TỔNG KẾT 1 THÁNG QUA ===", "", "", "", ""])
            writer.writerow(["Tổng số lượt VÀO:", f"{in_count} lượt", "", "", ""])
            writer.writerow(["Tổng số lượt RA:", f"{out_count} lượt", "", "", ""])
            writer.writerow(["Tổng DOANH THU:", f"{total_fee:,} VNĐ", "", "", ""])
        return True, f"✅ Đã lưu báo cáo 1 tháng: {filename}"
    except Exception as e: 
        return False, f"❌ Lỗi lưu file báo cáo 1 tháng: {e}"

def search_vehicle_history(plate_query):
    conn = get_connection()
    cursor = conn.cursor()
    search_pattern = f"%{plate_query}%"
    cursor.execute("SELECT plate_number, time_in, time_out, status, fee FROM ParkingRecords WHERE plate_number LIKE ? ORDER BY time_in DESC", (search_pattern,))
    records = cursor.fetchall()
    conn.close()
    return records

def get_revenue_chart_data():
    conn = get_connection()
    cursor = conn.cursor()
    start_date = (datetime.now() - timedelta(days=6)).strftime("%Y-%m-%d")
    cursor.execute("SELECT CAST(time_out AS DATE), SUM(fee) FROM ParkingRecords WHERE time_out IS NOT NULL AND CAST(time_out AS DATE) >= ? GROUP BY CAST(time_out AS DATE) ORDER BY CAST(time_out AS DATE)", (start_date,))
    rows = cursor.fetchall()
    conn.close()
    return [r[0].strftime("%d/%m") for r in rows], [r[1] or 0 for r in rows]

def add_to_blacklist(plate_number, reason):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO Blacklist (plate_number, reason) VALUES (?, ?)", (plate_number, reason))
        conn.commit()
        return True, f"🚫 Đã đưa {plate_number} vào Sổ Đen!"
    except pyodbc.IntegrityError: 
        return False, f"⚠️ Biển số {plate_number} đã nằm trong Sổ Đen từ trước rồi!"
    except Exception as e:
        return False, f"❌ Lỗi khi thêm: {e}"
    finally: conn.close()

def add_vip_face(plate_number, person_name, encoding_array):
    conn = get_connection()
    if not conn: return False
    cursor = conn.cursor()
    enc_str = json.dumps(encoding_array.tolist())
    try:
        cursor.execute("INSERT INTO MonthlyFaces (plate_number, person_name, face_encoding) VALUES (?, ?, ?)", (plate_number, person_name, enc_str))
        conn.commit()
        return True
    except Exception as e:
        print(f"Lỗi lưu khuôn mặt: {e}")
        return False
    finally: conn.close()

def get_vip_faces(plate_number):
    conn = get_connection()
    if not conn: return []
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT person_name, face_encoding FROM MonthlyFaces WHERE plate_number=?", (plate_number,))
        rows = cursor.fetchall()
    except: return []
    finally: conn.close()
    
    allowed_faces = []
    for row in rows:
        person_name = row[0]
        encoding_array = np.array(json.loads(row[1]))
        allowed_faces.append((person_name, encoding_array))
    return allowed_faces

def register_new_driver(username, password, fullname, dob, family_id, account_type='Family', phone=None):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    try:
        today = datetime.now().date()
        birth_date = datetime.strptime(dob, "%Y-%m-%d").date()
        age = today.year - birth_date.year - ((today.month, today.day) < (birth_date.month, birth_date.day))
        if age < 18:
            return False, "❌ Từ chối: Người dưới 18 tuổi không được tự đăng ký tài khoản. Vui lòng để cha/mẹ khai báo!"

        cursor.execute("""
            INSERT INTO Users (username, password, role, FullName, DateOfBirth, FamilyId, AccountType, PhoneNumber) 
            VALUES (?, ?, 'Driver', ?, ?, ?, ?, ?)
        """, (username, password, fullname, dob, family_id, account_type, phone))
        conn.commit()
        return True, "✅ Đăng ký tài khoản thành công!"
    except Exception as e:
        return False, f"❌ Lỗi: Có thể tên đăng nhập đã tồn tại ({e})"
    finally: conn.close()

def add_family_member(family_id, fullname, dob):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO FamilyMembers (FamilyId, FullName, DateOfBirth) VALUES (?, ?, ?)", (family_id, fullname, dob))
        conn.commit()
        return True, f"✅ Đã khai báo thành viên gia đình: {fullname}"
    except Exception as e:
        return False, f"❌ Lỗi khi khai báo: {e}"
    finally: conn.close()

def register_visitor(host_plate, guest_name, vehicle_type, guest_plate, time_in, time_out):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO Visitors (HostPlate, GuestName, GuestVehicleType, GuestPlate, ExpectedTimeIn, ExpectedTimeOut, Status)
            VALUES (?, ?, ?, ?, ?, ?, 'Pending')
        """, (host_plate, guest_name, vehicle_type, guest_plate, time_in, time_out))
        conn.commit()
        return True, f"✅ Đã khai báo khách {guest_name}."
    except Exception as e: return False, f"❌ Lỗi: {e}"
    finally: conn.close()

def check_guest_by_plate(guest_plate):
    conn = get_connection()
    if not conn: return {"is_registered": False}
    cursor = conn.cursor()
    cursor.execute("""
        SELECT v.GuestName, v.HostPlate, v.ExpectedTimeIn, v.ExpectedTimeOut, m.owner_name 
        FROM Visitors v LEFT JOIN MonthlyCards m ON v.HostPlate = m.plate_number
        WHERE v.GuestPlate = ? AND v.Status IN ('Pending', 'CheckedIn')
    """, (guest_plate,))
    guest_info = cursor.fetchone()
    conn.close()
    if guest_info:
        return {
            "is_registered": True, "guest_name": guest_info[0], "host_plate": guest_info[1],
            "expected_in": guest_info[2].strftime("%H:%M %d/%m/%Y") if guest_info[2] else "",
            "expected_out": guest_info[3].strftime("%H:%M %d/%m/%Y") if guest_info[3] else "",
            "host_name": guest_info[4] if guest_info[4] else "Khách lẻ"
        }
    return {"is_registered": False}

def get_visitor_history(host_plate):
    conn = get_connection()
    if not conn: return []
    cursor = conn.cursor()
    cursor.execute("""
        SELECT VisitorId, GuestName, GuestPlate, ExpectedTimeIn, ExpectedTimeOut, Status 
        FROM Visitors WHERE HostPlate = ? ORDER BY ExpectedTimeIn DESC
    """, (host_plate,))
    rows = cursor.fetchall()
    conn.close()

    result = []
    now = datetime.now()
    for r in rows:
        status = r[5]
        if status == 'Pending' and r[4]:
            if now > r[4]: status = 'Hết hạn'
            else:
                days_left = (r[4] - now).days
                if days_left == 0: status = 'Hết hạn hôm nay'
                else: status = f'Còn {days_left} ngày'
        result.append({
            "id": r[0], "guest_name": r[1], "guest_plate": r[2] if r[2] else "Đi bộ",
            "time_in": r[3].strftime("%d/%m/%Y") if r[3] else "", "status_str": status
        })
    return result

def renew_family_cards(family_id):
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT plate_number FROM MonthlyCards WHERE FamilyId = ?", (family_id,))
        vehicles = cursor.fetchall()
        if not vehicles: return False, f"Hộ {family_id} chưa đăng ký xe nào trong hệ thống!"

        for v in vehicles:
            cursor.execute("""
                UPDATE MonthlyCards 
                SET expiry_date = CASE 
                    WHEN expiry_date > GETDATE() THEN DATEADD(day, 30, expiry_date)
                    ELSE DATEADD(day, 30, GETDATE())
                END
                WHERE plate_number = ?
            """, (v[0],))
        conn.commit()
        return True, f"Đã gia hạn 30 ngày thành công cho {len(vehicles)} xe của hộ {family_id}."
    except Exception as e: return False, f"Lỗi: {e}"
    finally: conn.close()

def renew_single_card(plate_number):
    """Gia hạn thẻ tháng thêm 30 ngày cho một xe cụ thể"""
    conn = get_connection()
    if not conn: return False, "Lỗi kết nối CSDL!"
    cursor = conn.cursor()
    try:
        # Cộng dồn: Nếu hạn cũ > hôm nay thì lấy hạn cũ + 30, ngược lại lấy hôm nay + 30
        cursor.execute("""
            UPDATE MonthlyCards 
            SET expiry_date = CASE 
                WHEN expiry_date > GETDATE() THEN DATEADD(day, 30, expiry_date)
                ELSE DATEADD(day, 30, GETDATE())
            END,
            start_date = GETDATE()
            WHERE plate_number = ?
        """, (plate_number,))
        conn.commit()
        return True, "Gia hạn thành công 30 ngày."
    except Exception as e:
        return False, f"Lỗi: {e}"
    finally:
        conn.close()