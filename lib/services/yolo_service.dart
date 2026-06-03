/// YoloService 조건부 export
/// - 모바일 (dart:ffi 사용 가능): yolo_service_impl.dart → 실제 YOLOv8 TFLite 추론
/// - 웹 (dart:ffi 없음): yolo_service_stub.dart → 빈 결과 반환, Gemini 폴백으로 동작
export 'yolo_service_stub.dart'
    if (dart.library.ffi) 'yolo_service_impl.dart';
