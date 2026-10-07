# Báo cáo chuyển đổi: 2D pixel → First-Person POV (Godot 3D)

Lựa chọn đã xác nhận: **Godot 3D** là bản chính; làm Phase 1 (controller, shader, chữ tâm lý 3D, màn thử) và Phase 2 bằng **Python thủ tục, không cần API**. Nhân vật theo `MRAK_FIRST_APPEARANCE.md`: **không chân**.

Chạy thử: mở project bằng Godot 4.4+ → mở `scenes/fp/FP_TestRoom.tscn` → F6. Bản 2D (`Floor_0.tscn`) vẫn là main scene và không bị ảnh hưởng.

## 1. Đã kiểm chứng ra sao
Đã tải Godot 4.4.1 và chạy thật: nạp được mọi script/scene/shader (0 lỗi), chạy headless cả màn 3D lẫn `Floor_0` 1500 khung không lỗi runtime, và render bằng GL mềm để chụp ảnh (`docs/fp_preview/`). Đợt kiểm tra này cũng bắt được một lỗi cú pháp cũ trong `VoiceTextPool.gd` (đã sửa). Chưa thử trên GPU thật và chưa chơi bằng bàn phím/chuột; cảm giác điều khiển cần bạn thử.

## 2. Hướng đồ họa Brutalist + Shader
| Thành phần | File |
|---|---|
| Bề mặt bê tông/gỉ/lưới, triplanar theo toạ độ thế giới (không cần UV) và bị Erasure "ăn" | `shaders/fp/brutalist_surface.gdshader` |
| Lỗ đen Erasure: hình cầu đen bị xé nhiễu, viền static | `shaders/fp/erasure_void.gdshader` |
| Cánh tay la bàn: gân đen, ánh xanh ↔ đỏ chập chờn khi la bàn nói dối | `shaders/fp/arm_compass.gdshader` |
| White noise ở rìa màn hình, xé hình + tách RGB khi Red voice xâm nhập | `shaders/fp/fp_noise_overlay.gdshader` |
| Vũng coolant, đèn neon đỏ nhấp nháy, sương mù | trong `FPTestLevel.gd`, `FlickerLight.gd` |

## 3. Controller xác hoại tử (`FPController.gd`)
- Di chuyển theo nhịp **kéo thân**: tốc độ vọt lên rồi khựng, không mượt; chậm dần theo necrosis (đến −55%).
- Camera thấp 0.55 m, lắc theo nhịp kéo, giật theo nhịp tim cơ học 60 → 110 BPM (lub-dub).
- Space = nhắm mắt: màn hình đen kịt, chỉ còn âm thanh (tiếng tim), xóa chữ Đỏ, bán kính âm thanh còn 45.
- Q = bật la bàn (Vestige Needle). Dùng lại `GameManager`, `EventBus`, `blink`/`vestige_needle` có sẵn; WASD đăng ký lúc chạy.

## 4. Chữ tâm lý 3D (`PsychText3D.gd`)
Lời Trắng/Đỏ được bắn tia từ camera và khắc lên tường theo pháp tuyến bề mặt (Label3D); không có tường thì lơ lửng (billboard, hoặc `floating_only` cho cảnh zero-g). Pool 10 nhãn, tránh chồng lên nhau, bỏ qua sàn/trần. Nối thẳng vào `EventBus.firewall_speak` / `memory_leak_speak` nên `DialogueSystem` hoạt động nguyên vẹn.

## 5. Tài nguyên Phase 2 (Python, không API)
- `tools/gen_fp_textures.py` → `assets/textures/fp/{concrete,rust,mesh}.png` (tileable, tông lạnh tối).
- `tools/gen_fp_audio.py` → `assets/audio/fp/{fan_hum,metal_thud,erasure_crackle,heartbeat,drag}.wav`.
- Lưu ý: đây là âm thanh/texture tổng hợp để dựng khung; chất lượng cuối nên thay bằng nguồn xịn nếu cần.

## 6. Công nghệ
Phaser.js không dùng trong bản này. Web frontend chỉ giữ làm menu/demo thoại (không port sang Three.js, vì đã chọn Godot 3D).

## 7. Chưa làm / việc tiếp theo
- Kẻ địch 3D (Scavenger, Phantom, Watcher…) chưa port; hệ thống phát hiện vẫn nhận `mrak_collision_sound` theo toạ độ (x, z) nhưng AI hiện là 2D.
- Màn thử chỉ có một hành lang; chưa có zero-g, chưa nối Hồi 1.
- Cánh tay la bàn chỉ là hình khối cơ bản; có thể thay bằng mô hình sau.
- Âm thanh chưa qua bus riêng; chưa có hồi quy cho GPU thật.
