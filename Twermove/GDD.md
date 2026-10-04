# TWERMOVE — GAME DESIGN DOCUMENT (GDD)
## Phong Cách: Trauma-core / Glitch-core

---

## PHẦN 1: BỐN ĐỊNH LUẬT CỐT LÕI

---

### Định Luật 1 — Giao Diện Nội Tại (Diegetic UI) & Người Kể Chuyện Dối Trá

- **Không HUD truyền thống** — không thanh máu, không bản đồ, không menu nổi
- Thông tin sinh tồn hiển thị **trực tiếp lên cơ thể nhân vật** hoặc **khắc vào môi trường**
- Góc nhìn bị **bóp méo liên tục** bởi tổn thương tâm lý (Unreliable Narrator)
- Người chơi không phân biệt được thực tại và ảo giác
- **La Bàn Dối Trá** — không phải công cụ cứu hộ mà là "gông cùm dữ liệu":
  - Phản ứng với **ký ức**, không phải vật lý
  - 70% dẫn đúng hướng mảnh ký ức
  - 30% nhiễu, dẫn thẳng vào ổ quái vật

---

### Định Luật 2 — Phân Hạch Tâm Lý (Hệ Thống Độc Thoại)

Hai luồng ý thức song song, không ngừng giằng xé:

| Thuộc tính | Tiếng Nói Trắng/Xanh Nhạt | Tiếng Nói Đỏ/Đen Glitch |
|---|---|---|
| **Bản chất** | Giao thức tường lửa vô cảm | Rò rỉ bộ nhớ / hối hận |
| **Mục tiêu** | Ép tắt cảm xúc để sống sót | Lừa buông xuôi / phá hoại |
| **Visual** | Chữ nhạt màu, hướng dẫn đường đi | Chữ đỏ-đen, che khuất tầm nhìn |
| **Prefix ID** | `W_xxx` | `R_xxx` |

**Schema Dialogue (JSON tĩnh):**
```json
{
  "dialogues": [
    {
      "id": "W_001",
      "type": "survival_white",
      "text": "Phải tìm thêm lõi năng lượng, mày sắp tắt nguồn rồi.",
      "trigger": "energy_below_20"
    },
    {
      "id": "R_002",
      "type": "manipulation_red",
      "text": "Mày tưởng cái xác chắp vá này vẫn còn là con người sao?",
      "trigger": "near_phantom"
    }
  ]
}
```

**Trigger Conditions:**

| ID | Điều kiện kích hoạt |
|---|---|
| `energy_below_20` | Năng lượng < 20% |
| `standing_still_5s` | Đứng yên ≥ 5 giây |
| `near_phantom` | Phantom trong bán kính N unit |
| `hp_low` | HP < ngưỡng nguy hiểm |
| `eyes_closed_long` | Nhắm mắt > X giây |

---

### Định Luật 3 — Môi Trường Kể Chuyện & Âm Thanh

**Environmental Storytelling — cốt truyện truyền qua:**
- Vệt máu lơ lửng
- Máy thở tắt nguồn
- Kiến trúc phi logic
- Các căn phòng lặp lại

**Âm thanh — không nhạc du dương:**

| Nguồn | Mô tả |
|---|---|
| Quạt tản nhiệt | Nền liên tục, low rumble |
| Trái tim kim loại | Nhịp đập, tần số thay đổi theo HP |
| Xác Máy | Tiếng cọ xát kim loại |
| White noise | Chói tai khi hiểm họa đến gần |

---

### Định Luật 4 — Sinh Thái Suy Tàn & Hành Động Sinh Tồn

**Hai lớp kẻ thù:**

| Loại | Tên | Cơ chế |
|---|---|---|
| Vật lý | **Xác Máy Đói Khát** (Scavengers) | Khao khát năng lượng, tấn công cơ thể |
| Tâm lý | **Bóng Đen / Kẻ Mộng Du** (Phantoms) | Ảo giác, khai thác hối tiếc |

**Nguy hiểm môi trường tối thượng:**
- **The Erasure (Sự Xâm Thực)** — hố đen lỗi không gian → chạm = xóa nhân vật vĩnh viễn

**Động từ hành động cốt lõi (Player Verbs):**

| Hành động | Input | Hiệu ứng |
|---|---|---|
| **Lết** | Di chuyển | Nặng nề, chậm, tốn năng lượng |
| **Nhắm mắt** | Hold `Spacebar` | Màn đen, tắt bioluminescence, Scavengers mất aggro |

---

## PHẦN 2: QUY CHUẨN CODE

---

### State Machine — Hành Động "Nhắm Mắt"

```javascript
let isEyesClosed = false;

window.addEventListener('keydown', (e) => {
    if (e.code === 'Space') {
        isEyesClosed = true;
        UI.hideAllManipulativeText();   // Xóa chữ đỏ
        UI.renderBlackScreen();         // Màn đen
        Player.bioluminescence = 0;     // Tắt ánh sáng sinh học
        Enemies.Scavengers.loseAggro(Player); // Scavengers mất dấu
    }
});

window.addEventListener('keyup', (e) => {
    if (e.code === 'Space') {
        isEyesClosed = false;
        UI.removeBlackScreen();
        Player.bioluminescence = Player.defaultBioluminescence;
        // Chữ đỏ có thể hiện lại nếu Phantom ở gần
    }
});
```

---

### RNG — La Bàn Dối Trá

```javascript
function getCompassDirection() {
    const rng = Math.random();
    if (rng <= 0.70) {
        return Target.MemoryCore;      // 70% đúng hướng
    } else {
        return Target.ScavengerNest;   // 30% nhiễu, dẫn vào bẫy
    }
}
```

---

## CÂU HỎI MỞ / QUYẾT ĐỊNH CẦN ĐƯA RA

- [ ] **Tech stack chính thức** — HTML5 Canvas thuần / Phaser.js / Twine+SugarCube?
- [ ] **Góc nhìn** — Top-down / Side-scroller / First-person text-based?
- [ ] **Scope đầu tiên** — Bắt đầu từ phần nào? (Dialogue system / Player movement / World render)
- [ ] **Lưu trữ dialogue** — JSON file tĩnh serve qua Flask, hay hardcode trong JS?

---

*Version: 0.1 — Blank Slate*
*Last updated: 2026-09-30*
