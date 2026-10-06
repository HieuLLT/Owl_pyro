# PROJECT RULES &amp; AI MODEL INSTRUCTIONS: PHẾ TÍCH Ý THỨC (RUINS OF CONSCIOUSNESS)

&gt; **MỤC TIÊU:** File quy tắc này dùng để nhúng trực tiếp vào dự án (Cursor / AntiGravity / Windsurf / LLM Coding Agent). Giúp Model hiểu rõ bối cảnh dự án, tuân thủ khoanh vùng làm việc, bảo vệ kiến trúc game và **TỐI ƯU HÓA TOKEN QUOTA** tối đa.

---

## 1\. PHẠM VI DỰ ÁN &amp; BỐI CẢNH NỀN TẢNG (PROJECT CONTEXT)

* **Tên dự án:** Phế Tích Ý Thức (Ruins of Consciousness)
* **Thể loại:** 2D Lateral Psychological Horror / Narrative Platformer
* **Aesthetic:** Trauma-core, Glitch-core, Brutalist Architecture, Cybernetic Decay.
* **Cơ chế cốt lõi:**  
  * **Schizophrenic UI:** Độc thoại nội tâm giữa *Tiếng Nói Trắng* (Firewall/Sinh tồn) và *Tiếng Nói Đỏ* (Memory Leak/Hối hận).
  * **Diegetic Interface:** Không dùng HUD truyền thống, chỉ số chiếu trực tiếp lên cơ thể hoại tử 70% và môi trường.
  * **Sensory Deprivation:** Phím `Spacebar` (Nhắm mắt/Tắt nguồn phát sáng) để né bầy Xác Máy (Scavengers) và sóng âm Boss Buffer Overflow.
  * **La bàn Dối Trái (Vestige Needle):** Chỉ hướng ký ức nhưng bị nhiễu sóng.

---

## 2\. QUY TẮC KHOANH VÙNG LÀM VIỆC &amp; TỐI ƯU TOKEN QUOTA (CRITICAL)

### ⚠️ QUY TẮC 1: KHOANH VÙNG PHẠM VI (SCOPE BOUNDARY)

* **Chỉ thao tác trên File/Directory được chỉ định:** AI Model KHÔNG ĐƯỢC TỰ Ý quét (scan) hoặc đọc toàn bộ cây thư mục dự án nếu không được yêu cầu.
* **Chỉ chạy File được giao:** Chỉ thực thi (`node`, `npm test`, hoặc preview) file entrypoint của module đang phát triển (ví dụ: `src/scenes/Act1Scene.js`).
* **Không sửa chéo module:** Khi làm việc với `UI/SchizophrenicUI.js`, không tự ý thay đổi logic trong `Physics/PlayerController.js` trừ khi có lệnh trực tiếp.

### ⚡ QUY TẮC 2: TỐI ƯU HÓA CONTEXT WINDOW &amp; TOKEN QUOTA

* **Không đọc File đã hoạt động ổn định:** Khi cần tham chiếu interface, chỉ đọc file định nghĩa types/schema (`src/types/`) thay vì đọc toàn bộ file implementation dài hàng ngàn dòng.
* **Sửa đổi cục bộ (Targeted Edits):** Khi cập nhật/sửa bug, chỉ xuất phần code thay đổi (diff hoặc hàm cụ thể). **CẤM** xuất lại toàn bộ file code nếu file đó trên 100 dòng.
* **Tóm tắt ngắn gọn:** AI không giải thích dông dài, không nhắc lại lý thuyết. Chỉ báo cáo: **[Đã sửa gì] -&gt; [File nào] -&gt; [Cách test]**.

---

## 3\. CẤU TRÚC THƯ MỤC DỰ ÁN (PROJECT STRUCTURE MAPPING)

Nghiêm ngặt tuân thủ cấu trúc phân vùng làm việc:

```
/
├── .antigravity/            # Cấu hình AI Agent &amp; Prompts
│   └── PROJECT_RULES.md     # File quy tắc này
├── assets/                  # Tài nguyên tĩnh (Chỉ đọc khi cần check path)
│   ├── sprites/             # Player, Scavengers, Boss, Echoes
│   ├── audio/               # White noise, Glitch sfx, Heartbeat
│   └── shaders/             # Glitch effect, CRT, Erasure noise
├── src/                     # MÃ NGUỒN CHÍNH
│   ├── core/                # Game loop, State machine, Engine init
│   ├── entities/            # Player, Scavengers, BossBufferOverflow
│   ├── ui/                  # SchizophrenicUI (WhiteVoice, RedVoice), DiegeticOverlay
│   ├── scenes/              # BootScene, Act1Corridor, Act2MissingFloors
│   └── lore/                # DialogueData (JSON Schema), TruthCoreData
└── tests/                   # Script kiểm thử độc lập cho từng Module

```

---

## 4\. QUY CHUẨN KỸ THUẬT &amp; CODE CONVENTIONS

### A. Quy chuẩn Dialogue &amp; Schizophrenic UI

Mọi dữ liệu thoại **BẮT BUỘC** tuân thủ JSON Schema dưới đây. Model không được tự ý thay đổi cấu trúc data:

```
{
  "dialogue_id": "act1_phantom_encounter_01",
  "speaker": "WHITE_VOICE", // Hoặc "RED_VOICE"
  "display_type": "DIEGETIC_ENVIRONMENT", // DIEGETIC_BODY, SCREEN_GLITCH
  "text": "CẢNH BÁO: TỶ LỆ HOẠI TỬ VƯỢT QUÁ 70%. TẮT NGUỒN PHÁT SÁNG.",
  "glitch_intensity": 0.4,
  "trigger_condition": {
    "proximity_entity": "phantom_shield",
    "player_state": "SENSORY_ACTIVE"
  }
}

```

### B. Logic Nhắm mắt (Sensory Deprivation)

* Khi `PlayerState.isClosingEyes == true`:  
  * `Player.bioluminescence = 0`
  * `Player.footstepVolume = 0.1`
  * `UI.screenAlpha = 0.1` (Màn hình tối đen, chỉ hiện sóng âm nhẹ)
  * Bầy Scavengers mất mục tiêu tấn công.

---

## 5\. TEMPLATE KHỞI TẠO PROMPT CHO AI MODEL KHI MỞ SESSION MỚI

Mỗi khi người dùng mở session mới trên AntiGravity / Cursor, sao chép câu lệnh dưới đây:

&gt; *"Tôi đang phát triển game 'Phế Tích Ý Thức'. Hãy đọc `.antigravity/PROJECT_RULES.md`. Hôm nay chúng ta CHỈ LÀM VIỆC trên file: `[TÊN_FILE_CẦN_SỬA]`. Hãy tuân thủ nghiêm ngặt quy tắc khoanh vùng, chỉ đọc file liên quan trực tiếp và trả về code thay đổi dạng cục bộ để tiết kiệm Token Quota."*