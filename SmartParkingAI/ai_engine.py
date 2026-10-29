import cv2
import easyocr
from ultralytics import YOLO

# Tải model AI nhận diện vật thể (YOLOv8 nano - siêu nhẹ)
print("Đang khởi động AI YOLOv8...")
yolo_model = YOLO('yolov8n.pt') 

# Khởi tạo AI đọc chữ (EasyOCR) - hỗ trợ tiếng Anh/số
print("Đang khởi động AI EasyOCR...")
reader = easyocr.Reader(['en'], gpu=False) 

def process_frame(frame):
    """Nhận khung hình từ Camera, tìm và đọc biển số"""
    detected_plate = None
    
    # Cho YOLO quét khung hình
    results = yolo_model(frame, stream=True, verbose=False)
    
    for r in results:
        boxes = r.boxes
        for box in boxes:
            # Lấy tọa độ đóng khung vật thể
            x1, y1, x2, y2 = box.xyxy[0]
            x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2)
            
            # Cắt phần hình ảnh đó ra
            plate_crop = frame[y1:y2, x1:x2]
            
            # Bỏ qua nếu khung cắt bị lỗi hoặc quá nhỏ
            if plate_crop.size == 0:
                continue
                
            # Đưa phần cắt cho OCR đọc chữ
            ocr_result = reader.readtext(plate_crop)
            
            if ocr_result:
                # Nối các chữ lại, viết hoa và xóa khoảng trắng
                text = "".join([res[1] for res in ocr_result]).replace(" ", "").upper()
                
                # Biển số VN thường từ 7 - 9 ký tự (ví dụ: 59A12345)
                # Đặt điều kiện lọc sơ bộ để tránh nhiễu
                if 5 <= len(text) <= 12:
                    detected_plate = text
                    # Vẽ khung xanh lá và ghi chữ lên màn hình camera
                    cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                    cv2.putText(frame, text, (x1, y1 - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 255, 0), 2)
            
    return frame, detected_plate
