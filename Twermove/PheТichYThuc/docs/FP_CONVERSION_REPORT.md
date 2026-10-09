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

---

## 8. Đợt chỉnh sửa 09/10 (theo rà soát cốt truyện)

**Logic hai giọng nói (đối chiếu `SRC/cot-truyen...` và `GDD.md`):**
| Giọng | Theo cốt truyện | Trước | Nay |
|---|---|---|---|
| Trắng/xanh nhạt | chữ nhạt trên **da thịt hoặc mặt đất**, dẫn đường | khắc lên tường | dòng ngắn (≤38 ký tự) viết trên **cẳng tay**; dòng dài nằm trên **mặt đất** phía trước. Tường chỉ dành cho **hướng dẫn** (`PsychText3D.instruct`) |
| Đỏ/đen glitch | **che khuất tầm nhìn** (tới ~80% màn hình khi Phantom gào) | khắc lên tường | dán lên **màn hình** (`FPOverlay`, viền đen, to dần theo cường độ, 1–10 dòng); xóa ngay khi nhắm mắt |
| Nhắm mắt | **giữ** Space | bấm bật/tắt | giữ Space (chỉ bản FP; bản 2D vẫn bật/tắt, cần đồng bộ sau) |
| La bàn | 70% đúng hướng, 30% nhiễu dẫn vào ổ quái (GDD) | chỉ nhiễu theo necrosis | 70% chỉ mảnh ký ức, 30% chỉ lỗ đen Erasure, đổi mỗi 4–8 giây; nhắm mắt thì tắt đèn sinh học |

**Tầm nhìn kính lặn vỡ/đen:** `shaders/fp/fp_visor.gdshader` — viền đen không đều nuốt các góc, vết nứt tỏa từ hai điểm va chạm (hình ảnh bị lệch dọc vết nứt), mảnh kính rụng thành đen, hơi nước thở; độ hư hại tăng theo necrosis.

**Khối tay làm lại (`CompassArm.gd`):** hai tay dài lồi lõm sinh bằng mesh thủ tục, vết thương lõm lộ xương kim loại, vuốt cào sàn, hai vòng gông rỉ; tay trái cắm la bàn rỉ vẹo, rễ kim loại đen xuyên da (ánh xanh/đỏ). Hai tay **kéo luân phiên** theo nhịp lết (khớp mô tả мрак không chân).

**Thế giới dựng lại (`RuinGen.gd`, `FPTestLevel.gd`):** "Bãi Phế Liệu Ký Ức" — mặt đất chia mảng nghiêng có rãnh đứt gãy, mép ragged, vách đá treo; tường nghiêng có chỗ sập và đỉnh lởm chởm; cột gãy lòi cốt thép; tấm trần vỡ treo cáp, đèn neon treo xiên; đống đổ nát; vũng coolant hình bất định; ba lỗ đen Erasure (cái gần nhất mới "ăn" hình học); cuối đường là vách cụt nhìn ra các đảo bê tông lơ lửng trôi chậm trên vực thẳm nhiễu hạt (Hồi 2). Đường lết quanh co, đã kiểm tra bằng bot đi hết lộ trình (không rơi, không kẹt). Rơi xuống vực = bị xóa.

**Chưa làm:** bản 2D chưa đổi sang giữ-Space; chưa có hệ nhảy cho Hồi 2; mô hình tay/đảo vẫn là hình thủ tục, có thể thay bằng asset.
