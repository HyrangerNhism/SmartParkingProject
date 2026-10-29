import customtkinter as ctk
import cv2
from PIL import Image, ImageTk
import database
import ai_engine
import threading
from datetime import datetime
import time
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import os
import face_recognition
import urllib.request
import io

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class ParkingApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Smart Parking AI - Hệ Thống Quản Lý Bãi Xe Thông Minh")
        self.geometry("1150x850") 
        self.minsize(1000, 650)
        
        database.init_db()
        self.current_plate = None
        self.is_ai_running = False
        self.raw_frame = None 
        self.current_user_role = None 
        
        self.processing_plates = set()
        self.cooldown_until = {} 

        self.build_main_ui()
        self.withdraw() 
        self.open_login_screen()

    def open_login_screen(self):
        self.login_win = ctk.CTkToplevel(self)
        self.login_win.title("Đăng nhập Hệ thống An ninh")
        self.login_win.geometry("450x450")
        self.login_win.attributes('-topmost', True)
        self.login_win.protocol("WM_DELETE_WINDOW", self.destroy)

        ctk.CTkLabel(self.login_win, text="🛡️ SECURITY SYSTEM", font=ctk.CTkFont(family="Arial", size=24, weight="bold"), text_color="#00FFCC").pack(pady=(40, 10))
        ctk.CTkLabel(self.login_win, text="Đăng nhập để vào bảng điều khiển", font=ctk.CTkFont(size=14)).pack(pady=(0, 30))

        self.entry_user = ctk.CTkEntry(self.login_win, placeholder_text="Tài khoản", width=300, height=45, font=ctk.CTkFont(size=15))
        self.entry_user.pack(pady=10)
        self.entry_pass = ctk.CTkEntry(self.login_win, placeholder_text="Mật khẩu", show="*", width=300, height=45, font=ctk.CTkFont(size=15))
        self.entry_pass.pack(pady=10)
        self.lbl_error = ctk.CTkLabel(self.login_win, text="", text_color="red")
        self.lbl_error.pack(pady=5)

        def do_login():
            user = self.entry_user.get().strip()
            pwd = self.entry_pass.get().strip()
            role, msg = database.authenticate_user(user, pwd)
            if role:
                self.current_user_role = role
                self.login_win.destroy()
                self.deiconify() 
                self.apply_rbac_permissions() 
                self.log_message(f"👤 Nhân viên '{user}' vừa đăng nhập hệ thống.")
                self.cap = cv2.VideoCapture(0)
                self.update_video()
            else:
                self.lbl_error.configure(text=msg)

        ctk.CTkButton(self.login_win, text="ĐĂNG NHẬP", width=300, height=45, font=ctk.CTkFont(size=16, weight="bold"), fg_color="#1E3E62", hover_color="#152B44", command=do_login).pack(pady=20)

    def apply_rbac_permissions(self):
        if self.current_user_role == 'Guard':
            # Bảo vệ ĐƯỢC PHÉP Đăng ký vé tháng và Thêm Sổ đen (Giữ nguyên nút)
            # Chỉ ẩn các nút dành riêng cho Admin
            self.btn_cancel_vip.configure(state="disabled", fg_color="#444444") # Cấm xóa vé
            self.btn_stats.configure(state="disabled", fg_color="#444444")       # Cấm xem doanh thu
            self.btn_chart.configure(state="disabled", fg_color="#444444")       # Cấm xem biểu đồ
            self.btn_export.configure(state="disabled", fg_color="#444444")      # Cấm xuất Excel
            self.app_title.configure(text="🛡️ SMART PARKING AI - CHẾ ĐỘ BẢO VỆ")

    def build_main_ui(self):
        self.grid_rowconfigure(1, weight=1)
        self.grid_columnconfigure(0, weight=3)
        self.grid_columnconfigure(1, weight=2)

        self.header_frame = ctk.CTkFrame(self, fg_color="#1A222C", corner_radius=0, height=70)
        self.header_frame.grid(row=0, column=0, columnspan=2, sticky="ew")
        
        self.app_title = ctk.CTkLabel(self.header_frame, text="🛡️ SMART PARKING AI - QUẢN LÝ TỐI CAO", font=ctk.CTkFont(family="Segoe UI", size=24, weight="bold"), text_color="#00FFCC")
        self.app_title.pack(side="left", padx=30, pady=20)
        self.clock_label = ctk.CTkLabel(self.header_frame, text="00:00:00", font=ctk.CTkFont(family="Consolas", size=26, weight="bold"), text_color="#FFFFFF")
        self.clock_label.pack(side="right", padx=30, pady=20)

        self.left_frame = ctk.CTkFrame(self, corner_radius=10, border_width=2, border_color="#333333")
        self.left_frame.grid(row=1, column=0, padx=20, pady=20, sticky="nsew")
        ctk.CTkLabel(self.left_frame, text="CAMERA GIÁM SÁT", font=ctk.CTkFont(size=14, weight="bold"), text_color="#888888").pack(pady=(10, 0))
        self.video_label = ctk.CTkLabel(self.left_frame, text="Đang chờ Camera...")
        self.video_label.pack(expand=True, fill="both", padx=15, pady=10)
        self.plate_label = ctk.CTkLabel(self.left_frame, text="BIỂN SỐ: ĐANG QUÉT...", font=ctk.CTkFont(family="Consolas", size=32, weight="bold"), text_color="#00FF00")
        self.plate_label.pack(pady=(5, 10))
        
        self.manual_plate_entry = ctk.CTkEntry(self.left_frame, placeholder_text="Nhập tay biển số rồi bấm Enter để tự động Xử Lý...", width=400, height=40, font=ctk.CTkFont(size=14))
        self.manual_plate_entry.pack(pady=(0, 20))
        self.manual_plate_entry.bind("<Return>", self.handle_manual_entry)

        self.right_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.right_frame.grid(row=1, column=1, padx=(0, 20), pady=20, sticky="nsew")
        self.right_frame.grid_rowconfigure(0, weight=1)
        
        self.log_panel = ctk.CTkFrame(self.right_frame, corner_radius=10, border_width=2, border_color="#333333")
        self.log_panel.grid(row=0, column=0, sticky="nsew", pady=(0, 15))
        ctk.CTkLabel(self.log_panel, text="NHẬT KÝ HỆ THỐNG", font=ctk.CTkFont(size=12, weight="bold"), text_color="#888888").pack(pady=(5, 0))
        self.log_box = ctk.CTkTextbox(self.log_panel, font=ctk.CTkFont(size=13), fg_color="#1E1E1E")
        self.log_box.pack(fill="both", expand=True, padx=10, pady=10)

        self.control_panel = ctk.CTkFrame(self.right_frame, corner_radius=10, border_width=2, border_color="#333333")
        self.control_panel.grid(row=1, column=0, sticky="ew")

        self.in_out_frame = ctk.CTkFrame(self.control_panel, fg_color="transparent")
        self.in_out_frame.pack(fill="x", padx=15, pady=10)
        self.in_out_frame.grid_columnconfigure(0, weight=1)
        
        self.btn_in = ctk.CTkButton(self.in_out_frame, text="⬇️ CHO XE VÀO", font=ctk.CTkFont(size=16, weight="bold"), height=50, fg_color="#28A745", hover_color="#218838", command=self.handle_check_in)
        self.btn_in.grid(row=0, column=0, sticky="ew")

        self.btn_register = ctk.CTkButton(self.control_panel, text="📝 ĐĂNG KÝ VÉ THÁNG", font=ctk.CTkFont(size=13, weight="bold"), height=35, fg_color="#6C757D", command=self.open_registration_window)
        self.btn_register.pack(fill="x", padx=20, pady=4)

        self.btn_cancel_vip = ctk.CTkButton(self.control_panel, text="🗑️ HỦY THẺ THÁNG KHÁCH", font=ctk.CTkFont(size=13, weight="bold"), height=35, fg_color="#A52A2A", hover_color="#8B2500", command=self.open_cancel_window)
        self.btn_cancel_vip.pack(fill="x", padx=20, pady=4)
        
        self.btn_parked_list = ctk.CTkButton(self.control_panel, text="📋 DANH SÁCH XE ĐANG ĐỖ", font=ctk.CTkFont(size=13, weight="bold"), height=35, fg_color="#FD7E14", command=self.open_parked_list_window)
        self.btn_parked_list.pack(fill="x", padx=20, pady=4)
        self.btn_search = ctk.CTkButton(self.control_panel, text="🔍 TRA CỨU LỊCH SỬ", font=ctk.CTkFont(size=13, weight="bold"), height=35, fg_color="#6F42C1", command=self.open_search_window)
        self.btn_search.pack(fill="x", padx=20, pady=4)
        self.btn_stats = ctk.CTkButton(self.control_panel, text="📊 BÁO CÁO DOANH THU", font=ctk.CTkFont(size=13, weight="bold"), height=35, fg_color="#17A2B8", command=self.open_stats_window)
        self.btn_stats.pack(fill="x", padx=20, pady=4)
        self.btn_chart = ctk.CTkButton(self.control_panel, text="📈 BIỂU ĐỒ TĂNG TRƯỞNG", font=ctk.CTkFont(size=13, weight="bold"), height=35, fg_color="#D63384", command=self.open_chart_window)
        self.btn_chart.pack(fill="x", padx=20, pady=4)
        self.btn_export = ctk.CTkButton(self.control_panel, text="💾 XUẤT FILE EXCEL", font=ctk.CTkFont(size=13, weight="bold"), height=35, fg_color="#20C997", command=self.export_csv)
        self.btn_export.pack(fill="x", padx=20, pady=4)
        self.btn_blacklist = ctk.CTkButton(self.control_panel, text="🚫 THÊM VÀO SỔ ĐEN", font=ctk.CTkFont(size=13, weight="bold"), height=35, fg_color="#8B0000", hover_color="#660000", command=self.open_blacklist_window)
        self.btn_blacklist.pack(fill="x", padx=20, pady=(4, 15))

        self.update_clock()

    def update_clock(self):
        current_time = datetime.now().strftime("%H:%M:%S - %d/%m/%Y")
        self.clock_label.configure(text=current_time)
        self.after(1000, self.update_clock)

    def log_message(self, message):
        time_str = datetime.now().strftime("%H:%M:%S")
        self.log_box.insert("end", f"[{time_str}] {message}\n")
        self.log_box.see("end")

    def process_security_alert(self, msg):
        self.log_message(msg)
        if "🚨 BÁO ĐỘNG" in msg:
            image_path = None
            if self.raw_frame is not None:
                if not os.path.exists("Alert_Photos"):
                    os.makedirs("Alert_Photos")
                time_name = datetime.now().strftime("%Y%m%d_%H%M%S")
                image_path = f"Alert_Photos/alert_{time_name}.jpg"
                cv2.imwrite(image_path, self.raw_frame)
            threading.Thread(target=database.send_telegram_alert, args=(msg, image_path), daemon=True).start()

    def handle_check_in(self):
        manual_plate = self.manual_plate_entry.get().strip().upper()
        target_plate = manual_plate if manual_plate else self.current_plate
        if target_plate:
            success, msg = database.check_in(target_plate)
            self.process_security_alert(msg) 
            if success: 
                self.manual_plate_entry.delete(0, 'end') 
                self.cooldown_until[target_plate] = time.time() + 60
        else: self.log_message("⚠️ Lỗi: Không thấy biển số trước Camera!")

    def handle_manual_entry(self, event):
        plate = self.manual_plate_entry.get().strip().upper()
        if plate:
            if database.is_car_in(plate):
                if plate not in self.processing_plates:
                    self.processing_plates.add(plate)
                    self.auto_check_out(plate, self.raw_frame)
            else:
                self.handle_check_in()

    def auto_check_out(self, target_plate, frame):
        try:
            if not database.is_car_in(target_plate):
                return
            allowed_faces = database.get_vip_faces(target_plate)
            if False:  #if len(allowed_faces) > 0:
                self.log_message(f"🔍 [AUTO] Xe VIP {target_plate}. Hệ thống tự động quét khuôn mặt...")
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                current_face_encodings = face_recognition.face_encodings(rgb_frame)
                if not current_face_encodings:
                    self.process_security_alert(f"🚨 BÁO ĐỘNG: Không thấy mặt người lái xe {target_plate}!")
                    self.cooldown_until[target_plate] = time.time() + 15
                    return
                current_face = current_face_encodings[0]
                match_found = False
                matched_person = ""
                for person_name, saved_encoding in allowed_faces:
                    matches = face_recognition.compare_faces([saved_encoding], current_face, tolerance=0.5)
                    if matches[0]:
                        match_found = True
                        matched_person = person_name
                        break
                if match_found:
                    self.log_message(f"✅ Nhận diện chủ xe: {matched_person}. Khớp khuôn mặt!")
                else:
                    self.process_security_alert(f"🚨 CẢNH BÁO: Khuôn mặt không khớp danh sách gia đình xe {target_plate}! Khóa cổng!")
                    self.cooldown_until[target_plate] = time.time() + 15
                    return 
            success, msg = database.check_out(target_plate)
            self.process_security_alert(msg) 
            if success: 
                self.manual_plate_entry.delete(0, 'end')
            else:
                self.cooldown_until[target_plate] = time.time() + 15
        finally:
            if target_plate in self.processing_plates:
                self.processing_plates.remove(target_plate)

    def open_registration_window(self):
        win = ctk.CTkToplevel(self)
        win.title("Đăng ký Vé Tháng & Nhận Diện Khuôn Mặt")
        win.geometry("850x600")
        win.attributes('-topmost', True)

        f_left = ctk.CTkFrame(win, width=400)
        f_left.pack(side="left", fill="both", expand=True, padx=20, pady=20)
        
        ctk.CTkLabel(f_left, text="THÔNG TIN ĐĂNG KÝ VÉ THÁNG", font=("Arial", 18, "bold")).pack(pady=10)
        e_plate = ctk.CTkEntry(f_left, placeholder_text="Biển số xe (VD: 59A123)", width=300)
        e_plate.pack(pady=5)
        
        manual = self.manual_plate_entry.get().strip().upper()
        if manual or self.current_plate: 
            e_plate.insert(0, manual if manual else self.current_plate)
        
        e_name = ctk.CTkEntry(f_left, placeholder_text="Tên chủ xe/Gia đình", width=300)
        e_name.pack(pady=5)
        
        e_phone = ctk.CTkEntry(f_left, placeholder_text="Số điện thoại liên lạc", width=300)
        e_phone.pack(pady=5)
        
        e_role = ctk.CTkEntry(f_left, placeholder_text="Vai trò người lái (VD: Chồng, Vợ...)", width=300)
        e_role.pack(pady=5)

        e_family = ctk.CTkEntry(f_left, placeholder_text="Mã Hộ Gia đình (VD: FAM01)", width=300)
        e_family.pack(pady=5)

        self.face_captured = None 
        lbl_face = ctk.CTkLabel(f_left, text="Vui lòng nhìn thẳng vào Camera", font=("Arial", 12, "italic"))

        def capture_face():
            if self.raw_frame is not None:
                rgb = cv2.cvtColor(self.raw_frame, cv2.COLOR_BGR2RGB)
                encodings = face_recognition.face_encodings(rgb)
                if encodings:
                    self.face_captured = encodings[0]
                    lbl_face.configure(text="✅ Đã quét và mã hóa khuôn mặt thành công!", text_color="green")
                else:
                    lbl_face.configure(text="❌ Không tìm thấy khuôn mặt trước Camera!", text_color="red")

        ctk.CTkButton(f_left, text="📸 1. CHỤP MẶT NGƯỜI LÁI", fg_color="#1E3E62", height=40, command=capture_face).pack(pady=15)
        lbl_face.pack()

        f_right = ctk.CTkFrame(win, width=350, fg_color="#F0F0F0")
        f_right.pack(side="right", fill="both", padx=20, pady=20)
        
        ctk.CTkLabel(f_right, text="THANH TOÁN LỆ PHÍ", text_color="black", font=("Arial", 16, "bold")).pack(pady=10)
        ctk.CTkLabel(f_right, text="Gói vé tháng VIP: 30.000 VNĐ", text_color="blue", font=("Arial", 14)).pack()

        try:
            bank_id = "VCB"
            acc_no = "1039339285"
            amount = "30000"
            acc_name = "BAI%20GIU%20XE%20AI" 
            add_info = "Thanh%20toan%20ve%20thang"
            qr_url = f"https://img.vietqr.io/image/{bank_id}-{acc_no}-compact2.png?amount={amount}&addInfo={add_info}&accountName={acc_name}"
            req = urllib.request.Request(qr_url, headers={'User-Agent': 'Mozilla/5.0'})
            qr_data = urllib.request.urlopen(req).read()
            qr_img = Image.open(io.BytesIO(qr_data))
            qr_ctk = ctk.CTkImage(light_image=qr_img, dark_image=qr_img, size=(240, 280))
            ctk.CTkLabel(f_right, image=qr_ctk, text="").pack(pady=15)
        except Exception as e:
            print(f"Lỗi tải mã QR VietQR: {e}")
            ctk.CTkLabel(f_right, text="[LỖI TẢI MÃ QR CHUYỂN KHOẢN]", text_color="red").pack(pady=50)

        def confirm_save():
            plate = e_plate.get().strip().upper()
            role = e_role.get().strip()
            name = e_name.get().strip()
            phone = e_phone.get().strip()
            family_id = e_family.get().strip().upper() 
            
            if not family_id:
                self.log_message("⚠️ Vui lòng nhập Mã Hộ Gia đình (VD: FAM01)!")
                return

            success, msg = database.register_monthly_card(plate, name, phone, months=1, family_id=family_id) 
            
            if self.face_captured is not None and role:
                database.add_vip_face(plate, role, self.face_captured)
                
                if success:
                    self.log_message(f"✅ Đã đăng ký MỚI vé tháng & thêm khuôn mặt [{role}] cho xe {plate} (Hộ {family_id}).")
                else:
                    self.log_message(f"ℹ️ Biển số {plate} đã có vé. Đã thêm MẶT PHỤ [{role}] vào hồ sơ!")
                win.destroy()
            else:
                self.log_message("⚠️ Vui lòng chụp mặt và nhập vai trò trước khi lưu!")

        ctk.CTkButton(win, text="✅ 2. XÁC NHẬN THANH TOÁN & LƯU", height=50, fg_color="#28A745", command=confirm_save).pack(side="bottom", pady=(0, 10))

        # --- Nút Gia hạn toàn bộ xe của hộ (Chỉ hiện nếu là Admin) ---
        if self.current_user_role == 'Admin':
            def renew_family():
                family_id = e_family.get().strip().upper()
                if not family_id:
                    self.log_message("⚠️ Vui lòng nhập Mã Hộ Gia đình để gia hạn!")
                    return
                success, msg = database.renew_family_cards(family_id)
                self.log_message(msg)
                if success:
                    win.destroy()

            ctk.CTkButton(win, text="🔄 GIA HẠN TẤT CẢ XE CỦA HỘ NÀY", height=40, fg_color="#17A2B8", command=renew_family).pack(side="bottom", pady=(0, 20))

    def open_cancel_window(self):
        win = ctk.CTkToplevel(self)
        win.title("Hủy hồ sơ vé tháng")
        win.geometry("450x320")
        win.attributes('-topmost', True)

        ctk.CTkLabel(win, text="🗑️ HỦY VÉ THÁNG KHÁCH HÀNG", font=("Arial", 18, "bold"), text_color="#FF4C4C").pack(pady=20)
        ctk.CTkLabel(win, text="Hệ thống sẽ xóa toàn bộ thông tin thẻ và dữ liệu khuôn mặt gia đình.", font=("Arial", 11, "italic")).pack()

        e_plate = ctk.CTkEntry(win, placeholder_text="Nhập biển số xe cần xóa thẻ...", width=300, height=40, font=("Arial", 14))
        e_plate.pack(pady=20)

        manual = self.manual_plate_entry.get().strip().upper()
        if manual or self.current_plate:
            e_plate.insert(0, manual if manual else self.current_plate)

        def do_cancel_card():
            plate = e_plate.get().strip().upper()
            if not plate:
                self.log_message("⚠️ Vui lòng nhập biển số xe trước khi thực hiện!")
                return
            success, msg = database.delete_monthly_card(plate)
            self.log_message(msg)
            if success:
                win.destroy()

        ctk.CTkButton(win, text="💥 XÁC NHẬN HỦY VÀ XÓA HỒ SƠ", font=("Arial", 14, "bold"), height=45, fg_color="#DC3545", hover_color="#B22222", command=do_cancel_card).pack(pady=15)

    def open_stats_window(self):
        i, o, r = database.get_today_stats()
        win = ctk.CTkToplevel(self)
        win.title("Thống kê")
        win.geometry("350x250")
        win.attributes('-topmost', True)
        ctk.CTkLabel(win, text="📊 BÁO CÁO HÔM NAY", font=ctk.CTkFont(size=20, weight="bold")).pack(pady=20)
        ctk.CTkLabel(win, text=f"📥 Lượt xe vào:  {i} xe", font=ctk.CTkFont(size=16)).pack(pady=5)
        ctk.CTkLabel(win, text=f"📤 Lượt xe ra:   {o} xe", font=ctk.CTkFont(size=16)).pack(pady=5)
        ctk.CTkLabel(win, text=f"💰 Doanh thu: {r:,} VNĐ", font=ctk.CTkFont(size=18, weight="bold"), text_color="#FFD700").pack(pady=20)

    def open_parked_list_window(self):
        cars = database.get_parked_cars()
        win = ctk.CTkToplevel(self)
        win.geometry("450x500")
        win.attributes('-topmost', True)
        ctk.CTkLabel(win, text=f"📋 XE ĐANG TRONG BÃI ({len(cars)} xe)", font=ctk.CTkFont(size=18, weight="bold")).pack(pady=15)
        sf = ctk.CTkScrollableFrame(win, width=400, height=400)
        sf.pack(pady=10, padx=10, fill="both", expand=True)
        if not cars:
            ctk.CTkLabel(sf, text="Bãi xe trống!").pack(pady=20)
        else:
            for p, t in cars:
                ctk.CTkLabel(sf, text=f"🚗 {p} | Vào: {t.strftime('%H:%M:%S')}", font=ctk.CTkFont(family="Consolas", size=15)).pack(anchor="w", pady=5, padx=20)

    def open_search_window(self):
        win = ctk.CTkToplevel(self)
        win.title("Tra cứu lịch sử")
        win.geometry("600x500") 
        win.attributes('-topmost', True)
        
        ctk.CTkLabel(win, text="🔍 TRA CỨU LỊCH SỬ & BÁO CÁO", font=ctk.CTkFont(size=18, weight="bold")).pack(pady=15)
        f = ctk.CTkFrame(win, fg_color="transparent")
        f.pack(pady=5)
        
        e = ctk.CTkEntry(f, placeholder_text="Nhập biển số...", width=200)
        e.grid(row=0, column=0, padx=10)
        
        rf = ctk.CTkScrollableFrame(win, width=550, height=350)
        rf.pack(pady=15, fill="both", expand=True, padx=15)
        
        def search():
            for w in rf.winfo_children(): w.destroy()
            q = e.get().strip().upper()
            if not q: return
            res = database.search_vehicle_history(q)
            if not res: ctk.CTkLabel(rf, text="Không tìm thấy!").pack(pady=20)
            for r in res:
                t_in = r[1].strftime("%d/%m %H:%M") if r[1] else ""
                t_out = r[2].strftime("%d/%m %H:%M") if r[2] else "Chưa ra"
                fee = f"{r[4]:,}đ" if r[4] is not None else "0đ"
                c = "#00FF00" if r[3] == 'IN' else "#FFFFFF"
                s = "[TRONG BÃI]" if r[3] == 'IN' else "[ĐÃ RA]"
                ctk.CTkLabel(rf, text=f"{r[0]:<12} | {t_in} -> {t_out} | {s} | {fee}", font=ctk.CTkFont(family="Consolas", size=13), text_color=c, anchor="w").pack(fill="x", pady=4, padx=5)
        
        def export_1_month():
            success, msg = database.export_last_30_days_csv()
            self.log_message(msg)

        ctk.CTkButton(f, text="TÌM KIẾM", width=100, fg_color="#6F42C1", command=search).grid(row=0, column=1)
        ctk.CTkButton(f, text="💾 LƯU BÁO CÁO 1 THÁNG", width=160, fg_color="#20C997", hover_color="#17A2B8", command=export_1_month).grid(row=0, column=2, padx=10)

    def open_chart_window(self):
        dates, revs = database.get_revenue_chart_data()
        if not dates: return self.log_message("⚠️ Không có dữ liệu để vẽ biểu đồ!")
        win = ctk.CTkToplevel(self)
        win.title("Biểu đồ doanh thu")
        win.geometry("700x500")
        win.attributes('-topmost', True)
        fig, ax = plt.subplots(figsize=(6, 4), dpi=100)
        bars = ax.bar(dates, revs, color='#20C997', width=0.5)
        for b in bars: ax.text(b.get_x() + b.get_width()/2, b.get_height() + 500, f"{int(b.get_height()):,}đ", ha='center', va='bottom', fontsize=9)
        ax.set_title("Doanh thu 7 ngày qua", fontsize=14, fontweight='bold', pad=15)
        ax.set_ylabel("VNĐ")
        ax.grid(axis='y', linestyle='--', alpha=0.7)
        fig.tight_layout()
        canvas = FigureCanvasTkAgg(fig, master=win)
        canvas.draw()
        canvas.get_tk_widget().pack(fill="both", expand=True, padx=20, pady=20)

    def export_csv(self):
        success, msg = database.export_today_csv()
        self.log_message(msg)

    def open_blacklist_window(self):
        win = ctk.CTkToplevel(self)
        win.title("Thêm vào Sổ Đen")
        win.geometry("400x350")
        win.attributes('-topmost', True)
        ctk.CTkLabel(win, text="🚫 CẬP NHẬT SỔ ĐEN", font=("Arial", 18, "bold"), text_color="#FF4C4C").pack(pady=20)
        e_plate = ctk.CTkEntry(win, placeholder_text="Biển số cần cấm (VD: 99Z99999)", width=300)
        e_plate.pack(pady=10)
        manual = self.manual_plate_entry.get().strip().upper()
        if manual or self.current_plate: e_plate.insert(0, manual if manual else self.current_plate)
        e_reason = ctk.CTkEntry(win, placeholder_text="Lý do (VD: Xe trộm cắp, Chưa đóng phí...)", width=300)
        e_reason.pack(pady=10)
        def save_blacklist():
            plate = e_plate.get().strip().upper()
            reason = e_reason.get().strip()
            if plate and reason:
                success, msg = database.add_to_blacklist(plate, reason)
                self.log_message(msg)
                if success: win.destroy()
            else: self.log_message("⚠️ Vui lòng nhập đủ Biển số và Lý do!")
        ctk.CTkButton(win, text="XÁC NHẬN CẤM", command=save_blacklist, fg_color="#8B0000", hover_color="#660000").pack(pady=30)

    def _on_plate_detected(self, detected_plate, frame_copy):
        self.plate_label.configure(text=f"BIỂN SỐ: {detected_plate}")
        if database.is_car_in(detected_plate):
            if detected_plate in self.cooldown_until:
                if time.time() < self.cooldown_until[detected_plate]:
                    return
            if detected_plate not in self.processing_plates:
                self.processing_plates.add(detected_plate)
                self.auto_check_out(detected_plate, frame_copy)

    def process_ai_background(self, frame_copy):
        processed_frame, detected_plate = ai_engine.process_frame(frame_copy)
        if detected_plate:
            self.current_plate = detected_plate
            self.after(0, self._on_plate_detected, detected_plate, frame_copy)
        self.is_ai_running = False

    def update_video(self):
        ret, frame = self.cap.read()
        if ret:
            self.raw_frame = frame.copy() 
            display_frame = frame.copy()
            if not self.is_ai_running:
                self.is_ai_running = True
                threading.Thread(target=self.process_ai_background, args=(frame.copy(),), daemon=True).start()
            display_frame = cv2.resize(display_frame, (640, 480))
            rgb_image = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
            pil_image = Image.fromarray(rgb_image)
            imgtk = ctk.CTkImage(light_image=pil_image, dark_image=pil_image, size=(640, 480))
            self.video_label.imgtk = imgtk
            self.video_label.configure(image=imgtk, text="")
        self.after(30, self.update_video)

if __name__ == "__main__":
    app = ParkingApp()
    app.mainloop()