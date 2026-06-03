#!/bin/bash
# YOLOv8n TFLite 식재료 감지 모델 다운로드 스크립트
#
# 사용법:
#   chmod +x scripts/download_yolo_model.sh
#   ./scripts/download_yolo_model.sh
#
# 전제 조건: Python 3 + pip 설치 필요
#
# 출력: assets/models/food_yolov8n.tflite

set -e

MODEL_DIR="assets/models"
MODEL_FILE="$MODEL_DIR/food_yolov8n.tflite"
LABELS_FILE="$MODEL_DIR/food_labels.txt"

echo "🍱 한끼를 부탁해 — YOLOv8n 식재료 감지 모델 설정"
echo ""

if [ -f "$MODEL_FILE" ] && [ "$(wc -c < "$MODEL_FILE")" -gt 1000000 ]; then
  echo "✅ 모델이 이미 존재합니다: $MODEL_FILE ($(du -sh "$MODEL_FILE" | cut -f1))"
  exit 0
fi

mkdir -p "$MODEL_DIR"

# ── 방법 1: Python ultralytics 패키지로 YOLOv8n 내보내기 ──────────────────
echo "📦 방법 1: Python ultralytics로 YOLOv8n TFLite 내보내기..."
echo "   (약 1-2분 소요, 최초 실행 시 모델 자동 다운로드됨)"
echo ""

if python3 -c "import ultralytics" 2>/dev/null; then
  python3 - << 'PYEOF'
from ultralytics import YOLO
import shutil, os

print("  YOLOv8n 모델 로드 중...")
model = YOLO("yolov8n.pt")

print("  TFLite 형식으로 내보내기...")
# int8 quantization (파일 크기 ~3MB, 속도 빠름)
model.export(format="tflite", int8=True, data=None)

# 생성된 파일 이동
src = "yolov8n_saved_model/yolov8n_integer_quant.tflite"
if not os.path.exists(src):
    src = "yolov8n_saved_model/yolov8n_full_integer_quant.tflite"
if not os.path.exists(src):
    # float32 fallback
    model.export(format="tflite")
    src = "yolov8n_saved_model/yolov8n_float32.tflite"

dst = "assets/models/food_yolov8n.tflite"
shutil.copy(src, dst)
print(f"  ✅ 모델 저장: {dst}")

# 임시 디렉터리 정리
shutil.rmtree("yolov8n_saved_model", ignore_errors=True)
os.remove("yolov8n.pt") if os.path.exists("yolov8n.pt") else None
PYEOF
  echo ""
  echo "✅ YOLOv8n TFLite 모델 설정 완료!"
else
  echo "  ⚠️  ultralytics 패키지 없음. 설치 중..."
  pip3 install ultralytics -q
  python3 - << 'PYEOF'
from ultralytics import YOLO
import shutil, os

model = YOLO("yolov8n.pt")
model.export(format="tflite")
src = "yolov8n_saved_model/yolov8n_float32.tflite"
shutil.copy(src, "assets/models/food_yolov8n.tflite")
shutil.rmtree("yolov8n_saved_model", ignore_errors=True)
os.remove("yolov8n.pt") if os.path.exists("yolov8n.pt") else None
print("✅ 모델 저장: assets/models/food_yolov8n.tflite")
PYEOF
fi

echo ""
echo "📌 기본 모델: YOLOv8n (COCO 80 classes)"
echo "   인식 가능 식재료: 사과(apple), 바나나(banana), 오렌지(orange),"
echo "                    브로콜리(broccoli), 당근(carrot), 샌드위치(sandwich) 등"
echo ""
echo "🔄 더 정확한 한국 식재료 인식을 원한다면:"
echo "   1. https://universe.roboflow.com 에서 'food detection' 또는 'vegetable' 검색"
echo "   2. YOLOv8 TFLite 모델 다운로드"
echo "   3. assets/models/food_yolov8n.tflite 로 저장"
echo "   4. 레이블 파일 → assets/models/food_labels.txt 로 교체"
