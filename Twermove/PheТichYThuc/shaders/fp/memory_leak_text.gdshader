// memory_leak_text.gdshader — CanvasItem shader áp lên từng RichTextLabel của Tiếng Nói Đỏ.
//
// MỤC ĐÍCH:
//   Biến văn bản từ "decal 2D dán cứng" thành "hiện tượng rò rỉ bộ nhớ" thực sự:
//   * Không có nền đặc (background = hoàn toàn trong suốt)
//   * Screen tearing ngang từng dòng chữ (horizontal scanline glitch)
//   * White noise hạt mịn phủ lên vùng chữ
//   * RGB split nhẹ — chữ "vỡ" theo chiều ngang
//   * Flicker xung theo nhịp — không đều, không đoán được
//
// CÁCH DÙNG (GDScript):
//   var mat = ShaderMaterial.new()
//   mat.shader = preload("res://shaders/fp/memory_leak_text.gdshader")
//   mat.set_shader_parameter("intensity", 0.8)
//   label.material = mat

shader_type canvas_item;

// intensity: 0.0 = thì thầm (ít glitch), 1.0 = gào thét (tearing mạnh)
uniform float intensity : hint_range(0.0, 1.0) = 0.5;

// noise_fps: tốc độ cập nhật hạt nhiễu (thấp hơn = hạt thô hơn, film-grain)
uniform float noise_fps : hint_range(4.0, 30.0) = 12.0;

// rgb_split: độ tách kênh màu (tạo cảm giác "dữ liệu bị hỏng")
uniform float rgb_split : hint_range(0.0, 0.05) = 0.008;

// scan_bands: số dải tearing theo chiều ngang
uniform float scan_bands : hint_range(4.0, 32.0) = 14.0;

// Xác suất một dải bị tear tại mỗi frame (glitch-core: không đều)
uniform float tear_prob : hint_range(0.0, 1.0) = 0.28;

// ── hash functions ────────────────────────────────────────────────────────────

float hash11(float p) {
    p = fract(p * 127.1);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// ── main ──────────────────────────────────────────────────────────────────────

void fragment() {
    float tick    = floor(TIME * noise_fps);
    vec2  uv      = UV;
    vec2  scr_uv  = SCREEN_UV;

    // ── 1. Horizontal tearing (screen tear per scanline band) ────────────────
    //    Mỗi dải ngang có xác suất `tear_prob` bị lệch sang trái/phải.
    //    Glitch-core: chỉ một số dải bị ảnh hưởng, không phải tất cả.
    float band     = floor(uv.y * scan_bands);
    float tear_rng = hash21(vec2(band, tick));
    float tear_on  = step(1.0 - tear_prob * intensity, tear_rng);
    float tear_amt = (hash21(vec2(band, tick + 3.0)) - 0.5) * 0.18 * intensity * tear_on;

    // Lệch UV theo chiều ngang — chữ "trượt" sang một bên thoáng qua
    uv.x = clamp(uv.x + tear_amt, 0.0, 1.0);

    // ── 2. RGB channel split ──────────────────────────────────────────────────
    //    Đọc kênh R từ vị trí lệch trái, B lệch phải → chữ có viền màu.
    //    Tăng lên khi intensity cao, giảm về 0 khi thì thầm.
    float split = rgb_split * (0.3 + 0.7 * intensity);
    vec4  col_r  = texture(TEXTURE, vec2(clamp(uv.x + split, 0.0, 1.0), uv.y));
    vec4  col_c  = texture(TEXTURE, uv);
    vec4  col_b  = texture(TEXTURE, vec2(clamp(uv.x - split, 0.0, 1.0), uv.y));

    // Hợp kênh: R từ lệch phải, G từ giữa, B từ lệch trái
    vec4 col = vec4(col_r.r, col_c.g, col_b.b, col_c.a);

    // ── 3. Transparent background fix ────────────────────────────────────────
    //    Vùng alpha = 0 (background của RichTextLabel) phải HOÀN TOÀN trong suốt.
    //    Không áp bất kỳ hiệu ứng nào lên vùng đó.
    if (col.a < 0.02) {
        discard;  // drop pixel hoàn toàn — không có ô đỏ đặc nào xuất hiện
    }

    // ── 4. White noise hạt mịn ────────────────────────────────────────────────
    //    Phủ lên vùng CHỮ (alpha > 0), không phủ lên nền.
    //    Chỉ hiện trên pixel có nội dung.
    float grain_uv = hash21(floor(scr_uv * vec2(240.0, 135.0)) + vec2(tick * 0.71, tick));
    float grain    = (grain_uv - 0.5) * 0.22 * intensity * col.a;
    col.rgb        = clamp(col.rgb + vec3(grain), 0.0, 1.0);

    // ── 5. Flicker xung ───────────────────────────────────────────────────────
    //    Độ sáng dao động không đều theo thời gian.
    //    Glitch-core: không sin mượt — là hash từng frame.
    float flicker_t  = floor(TIME * 18.0);
    float flicker    = 1.0 - 0.18 * intensity * step(0.82, hash11(flicker_t));
    col.rgb         *= flicker;

    COLOR = col;
}
