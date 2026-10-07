# мрак — Ghi chú diện mạo lần đầu xuất hiện (First Appearance Build)

Tài liệu gốc cho mọi bản trình bày của nhân vật (sprite 2D, POV 3D, cutscene). Nếu chỗ nào mâu thuẫn, tài liệu này thắng.

## 1. Nguyên tắc cốt lõi

**мрак được chế tạo để BÒ, không phải để đi.** Khi tỉnh dậy lần đầu, cơ thể không có chân và không có bất kỳ bộ phận robot nào mô phỏng chân (không khớp gối, không bàn chân kim loại, không piston chân).

| Hạng mục | Trạng thái ở lần xuất hiện đầu |
|---|---|
| Chân / bộ phận giống chân | **VÔ HIỆU HÓA — không tồn tại** |
| Thân dưới | Kết thúc ở một gốc xé rách (stump): đầu cột sống kim loại ố lòi ra, vài dây cáp lê theo phía sau |
| Di chuyển | Hai tay quá dài chống và kéo thân; thân lê trên sàn |
| Tư thế mặc định | Gù, nửa thân trên chống lên bằng hai tay (idle); thấp hơn nữa khi nằm sấp (crouch) |
| Nhảy | Không có (đã đúng với code: Mrak.gd không có nhảy) |
| Leo | Chỉ bằng tay, thân dưới và dây cáp buông thõng |

## 2. Cấu tạo (từ trên xuống)

1. **Đầu** — không mặt, không mắt/miệng. Lớp nhiễu tĩnh (static) phủ liên tục; shader `mrak_glitch_body` cộng thêm nhiễu sống.
2. **Cổ** — quạt tản nhiệt gỉ nằm trong cổ họng, quay chậm; bị kẹt ở trạng thái xấu.
3. **Thân** — ~70% thịt hoại tử xám phủ khung xương kim loại ố. Ngực vỡ lộ xương sườn gãy và **tim cơ học** (vỏ gỉ, lõi xanh lục lam đập theo `heartbeat_bpm`).
4. **Cánh tay gần (trái trong POV)** — bị rễ đen của la bàn đâm xuyên, phát sáng xanh. Đây là cánh tay duy nhất người chơi thấy ở góc nhìn thứ nhất.
5. **Cánh tay xa** — tối hơn, chỉ để cân đối hình dáng 2D.
6. **Hai tay** — dài bất thường (13+15 px so với thân ~27 px), ba ngón vuốt kim loại.
7. **Gốc thân dưới** — rách, dây cáp đen/gỉ/xanh lục lam lê theo; rò **nước làm mát** xanh lục ở hông.

## 3. Hệ quả cho từng hệ thống

- **Sprite 2D** (`tools/gen_mrak_sprite.py`): đã vẽ lại không chân (15 khung, tên animation giữ nguyên). Muốn đổi hình, sửa hàm `pose()` rồi chạy lại script.
- **POV 3D** (`scripts/fp/`): không có thân dưới trong khung nhìn. Camera đặt thấp (gần sàn) vì мрак bò. Chỉ có cánh tay la bàn ở góc dưới trái. Bước "chân" = nhịp kéo thân: mỗi chu kỳ là một lần tay phải kéo rồi tay trái kéo; âm thanh là tiếng lê, không phải bước chân.
- **Va chạm / âm thanh:** capsule 2D giữ nguyên; trong 3D dùng capsule nằm thấp (cao 0.7m). Âm lê kéo phát ra bán kính `GameManager.current_sound_radius`; nhắm mắt thì gần như im lặng.
- **Lore:** "mất chân" không phải chấn thương, mà là thiết kế gốc. Bất kỳ đoạn thoại nào nhắc "đứng dậy / bước đi" phải được viết là ký ức của một cơ thể khác.

## 4. Việc cần xác nhận về sau

- Sprite 2D hiện lệch trái khoảng 5 px so với tâm node (thân dài, đuôi cáp ở bên trái). Chấp nhận được; nếu cần thì dịch collision thay vì dịch sprite (vì `flip_h`).
- Animation `climb` đã có nhưng chưa được gọi trong `Mrak.gd`.
