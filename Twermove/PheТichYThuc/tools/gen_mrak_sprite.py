#!/usr/bin/env python3
"""
gen_mrak_sprite.py — procedural pixel-art generator for мрак (Phế Tích Ý Thức).

Draws every animation frame of the protagonist with Pillow (no external art tools),
writes individual 64x64 PNGs (one file per frame, so the shader's UV is 0..1 per frame),
a contact sheet for quick review, and a ready-to-use Godot SpriteFrames resource.

    python3 tools/gen_mrak_sprite.py

Output (relative to the project root):
    assets/sprites/mrak/<anim>_<n>.png     individual frames
    assets/sprites/mrak/mrak_frames.tres   SpriteFrames (res:// paths)
    assets/sprites/mrak/_contact_sheet.png preview (not used by the game)

Design (from the lore):
  * ~70% necrotic grey flesh over a tarnished-metal skeleton
  * broken open chest: rib cage + a rusty mechanical heart with a cyan core
  * rusty radiator fan lodged in the throat
  * faceless, glitched head (the mrak_glitch_body shader adds live static on top)
  * near arm pierced by black compass roots that end in a cyan light
  * coolant leaking from the side, hunched crawling posture, over-long arms
Facing right; flip_h is handled in Mrak.gd. Feet rest on y = 62 of a 64x64 frame, so with
the AnimatedSprite2D at position (0, -32) the soles sit on the node origin.
"""
import math
import os
import random
import zlib

from PIL import Image, ImageDraw

W = H = 64
GROUND = 61  # foot-centre target; soles end at y = 62

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
OUT = os.path.join(ROOT, "assets", "sprites", "mrak")

# ── limited palette (10 colours + outline) ──────────────────────────────────
PAL = {
    "outline": (13, 11, 16, 255),
    "flesh_d": (52, 55, 60, 255),
    "flesh_m": (88, 93, 98, 255),
    "flesh_l": (124, 129, 134, 255),
    "rust_d": (74, 38, 22, 255),
    "rust": (142, 80, 44, 255),
    "tarn": (176, 150, 96, 255),
    "cyan": (25, 230, 200, 255),
    "cyan_d": (11, 122, 110, 255),
    "root": (6, 6, 10, 255),
}
C = PAL

ARM = (13, 15)   # over-long arms
LEG = (12, 13)

# animation name -> (frame count, fps, loop)
ANIMS = {
    "idle": (2, 3.0, True),
    "crawl": (4, 8.0, True),
    "crouch_idle": (1, 1.0, True),
    "crawl_low": (4, 6.0, True),
    "fall": (2, 8.0, True),
    "climb": (2, 6.0, True),
}


# ── geometry helpers ────────────────────────────────────────────────────────
def ik(root, target, l1, l2, bend):
    """Two-bone IK in image space (y down). bend=+1 elbow behind, -1 knee in front."""
    dx, dy = target[0] - root[0], target[1] - root[1]
    d = math.hypot(dx, dy)
    d = max(min(d, l1 + l2 - 0.01), abs(l1 - l2) + 0.01)
    a = math.atan2(dy, dx)
    cosb = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    b = math.acos(max(-1.0, min(1.0, cosb)))
    ang = a + bend * b
    joint = (root[0] + l1 * math.cos(ang), root[1] + l1 * math.sin(ang))
    end = (root[0] + d * math.cos(a), root[1] + d * math.sin(a))
    return joint, end


def ipt(p):
    return (int(round(p[0])), int(round(p[1])))


def seg(d, p, q, w, col):
    d.line([ipt(p), ipt(q)], fill=col, width=w)
    r = w / 2.0
    for c in (p, q):
        cx, cy = ipt(c)
        d.ellipse([cx - r + 0.5, cy - r + 0.5, cx + r - 0.5, cy + r - 0.5], fill=col)


def limb(d, root, target, lens, bend, w_up, w_lo, far=False, hand=True):
    """Flesh limb with an exposed tarnished-metal bone along the lower segment."""
    joint, end = ik(root, target, lens[0], lens[1], bend)
    flesh = C["flesh_d"] if far else C["flesh_m"]
    seg(d, root, joint, w_up, flesh)
    seg(d, joint, end, w_lo, flesh)
    bone = C["rust_d"] if far else C["tarn"]
    d.line([ipt(joint), ipt(end)], fill=bone, width=1)
    # torn flesh at the joint: a rusty bolt
    jx, jy = ipt(joint)
    d.point((jx, jy), fill=C["rust"] if not far else C["rust_d"])
    ex, ey = ipt(end)
    tip = C["rust_d"] if far else C["tarn"]
    if hand:
        # three long claw-fingers pointing along the forearm direction, spread slightly
        ux, uy = end[0] - joint[0], end[1] - joint[1]
        n = math.hypot(ux, uy) or 1.0
        ux, uy = ux / n, uy / n
        for spread in (-0.45, 0.0, 0.45):
            ca, sa = math.cos(spread), math.sin(spread)
            fx, fy = ux * ca - uy * sa, ux * sa + uy * ca
            d.line([(ex, ey), (round(ex + fx * 4), round(ey + fy * 4))], fill=tip, width=1)
    else:
        # foot: flat metal paw reaching forward
        d.line([(ex - 1, ey + 1), (ex + 4, ey + 1)], fill=tip, width=1)
        d.line([(ex - 1, ey), (ex + 2, ey)], fill=flesh, width=1)
    return joint, end


# ── per-frame poses ─────────────────────────────────────────────────────────
def pose(anim, i):
    P = dict(drip=0, fan=0.0, glitch_seed=i)
    if anim == "idle":
        b = i
        P.update(hip=(27, 40), sh=(35, 27 - b), head=(39, 15 - b),
                 na=(41, 52 + b), fa=(32, 50 + b), nl=(31, GROUND), fl=(22, GROUND), drip=i * 2)
    elif anim == "crawl":
        ph = i / 4.0 * 2.0 * math.pi
        sw, cs = math.sin(ph), math.cos(ph)
        bob = abs(sw)
        P.update(hip=(24, 42 + bob), sh=(37, 33 + bob), head=(45, 22 + bob),
                 na=(46 + 7 * sw, GROUND - 6 * max(0, cs)),
                 fa=(46 - 7 * sw, GROUND - 6 * max(0, -cs)),
                 nl=(22 - 6 * sw, GROUND - 5 * max(0, -cs)),
                 fl=(22 + 6 * sw, GROUND - 5 * max(0, cs)), drip=i)
    elif anim == "crouch_idle":
        P.update(hip=(19, 51), sh=(33, 48), head=(43, 47),
                 na=(42, GROUND), fa=(36, GROUND), nl=(24, GROUND), fl=(15, GROUND), drip=1)
    elif anim == "crawl_low":
        ph = i / 4.0 * 2.0 * math.pi
        sw, cs = math.sin(ph), math.cos(ph)
        bob = abs(sw) * 0.8
        P.update(hip=(19, 51 + bob), sh=(33, 48 + bob), head=(43, 47 + bob),
                 na=(43 + 5 * sw, GROUND - 4 * max(0, cs)),
                 fa=(43 - 5 * sw, GROUND - 4 * max(0, -cs)),
                 nl=(23 - 4 * sw, GROUND - 4 * max(0, -cs)),
                 fl=(17 + 4 * sw, GROUND - 4 * max(0, cs)), drip=i)
    elif anim == "fall":
        P.update(hip=(30, 38), sh=(34, 25), head=(36, 13),
                 na=(44, 8 + 2 * i), fa=(25, 12 - 2 * i),
                 nl=(26, 60 - 2 * i), fl=(35, 57 - 2 * i), drip=3 + i * 3)
    elif anim == "climb":
        if i == 0:
            P.update(hip=(28, 44), sh=(32, 29), head=(34, 18),
                     na=(37, 14), fa=(33, 24), nl=(30, 54), fl=(27, GROUND), drip=1)
        else:
            P.update(hip=(28, 44), sh=(32, 29), head=(34, 18),
                     na=(36, 23), fa=(34, 13), nl=(30, 59), fl=(28, 52), drip=2)
    P["fan"] = i * 0.9
    return P


# ── frame renderer ──────────────────────────────────────────────────────────
def render(anim, i):
    P = pose(anim, i)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rng = random.Random(1000 + zlib.crc32(anim.encode()) % 997 * 7 + i)

    hip, sh, head = P["hip"], P["sh"], P["head"]
    ux, uy = sh[0] - hip[0], sh[1] - hip[1]
    L = math.hypot(ux, uy) or 1.0
    ux, uy = ux / L, uy / L
    nx, ny = -uy, ux  # forward normal (n.x > 0 when upright)

    # far limbs (darker, behind the body)
    limb(d, sh, P["fa"], ARM, +1, 4, 3, far=True)
    limb(d, hip, P["fl"], LEG, -1, 5, 4, far=True, hand=False)

    # torso
    def off(p, k):
        return (p[0] + nx * k, p[1] + ny * k)

    torso = [off(hip, -5), off(sh, -6), off(sh, 6), off(hip, 5)]
    d.polygon([ipt(p) for p in torso], fill=C["flesh_m"])
    # back shading
    d.polygon([ipt(p) for p in (off(hip, -5), off(sh, -6), off(sh, -2), off(hip, -2))], fill=C["flesh_d"])
    # spine: tarnished vertebrae along the back
    for k in range(0, int(L), 3):
        sp = (hip[0] + ux * k + nx * -4.5, hip[1] + uy * k + ny * -4.5)
        d.point(ipt(sp), fill=C["tarn"])

    # broken-open chest with the mechanical heart
    cc = (hip[0] + ux * L * 0.62 + nx * 1.5, hip[1] + uy * L * 0.62 + ny * 1.5)
    cx, cy = ipt(cc)
    d.ellipse([cx - 4, cy - 5, cx + 4, cy + 5], fill=C["root"])
    for k in (-3, 0, 3):  # broken ribs
        d.line([(cx - 4, cy + k), (cx + 4, cy + k)], fill=C["rust_d"], width=1)
    d.line([(cx + 4, cy - 4), (cx + 6, cy - 6)], fill=C["tarn"], width=1)  # rib splinter
    d.line([(cx + 4, cy + 3), (cx + 6, cy + 5)], fill=C["tarn"], width=1)
    d.rectangle([cx - 2, cy - 2, cx + 1, cy + 1], fill=C["rust"])          # heart housing
    d.rectangle([cx - 1, cy - 1, cx, cy], fill=C["cyan"])                  # core
    d.point((cx - 2, cy + 2), fill=C["cyan_d"])
    d.point((cx + 1, cy - 2), fill=C["cyan_d"])

    # coolant leak from the flank
    dx0, dy0 = ipt((hip[0] + ux * L * 0.25 + nx * 5, hip[1] + uy * L * 0.25 + ny * 5))
    drip = P["drip"]
    d.point((dx0, dy0), fill=C["cyan_d"])
    for k in range(1, 3 + drip):
        d.point((dx0, min(dy0 + k, 62)), fill=C["cyan_d"])
    d.point((dx0, min(dy0 + 3 + drip, 62)), fill=C["cyan"])

    # near leg
    limb(d, hip, P["nl"], LEG, -1, 5, 4, hand=False)

    # neck + radiator fan in the throat
    neck = (sh[0] + (head[0] - sh[0]) * 0.45, sh[1] + (head[1] - sh[1]) * 0.45)
    seg(d, sh, neck, 5, C["flesh_d"])
    fx, fy = ipt(neck)
    d.ellipse([fx - 3, fy - 3, fx + 3, fy + 3], fill=C["rust_d"])
    for s in (0.0, math.pi / 2):
        a = P["fan"] + s
        d.line([(fx - round(2.6 * math.cos(a)), fy - round(2.6 * math.sin(a))),
                (fx + round(2.6 * math.cos(a)), fy + round(2.6 * math.sin(a)))], fill=C["tarn"], width=1)
    d.point((fx, fy), fill=C["cyan_d"])

    # head: faceless, static-glitched
    hx, hy = ipt(head)
    d.ellipse([hx - 5, hy - 6, hx + 5, hy + 6], fill=C["flesh_d"])
    d.ellipse([hx - 4, hy - 6, hx + 4, hy + 3], fill=C["flesh_m"])
    for row in range(-5, 6):
        if rng.random() < 0.55:
            x0 = hx - 4 + rng.randint(0, 5)
            w = rng.randint(1, 3)
            col = rng.choice([C["flesh_l"], C["outline"], C["cyan_d"], C["flesh_d"]])
            d.line([(x0, hy + row), (min(x0 + w, hx + 4), hy + row)], fill=col, width=1)
    d.point((hx + rng.randint(-3, 3), hy + rng.randint(-4, 4)), fill=C["cyan"])

    # near arm, pierced by compass roots
    j, e = limb(d, sh, P["na"], ARM, +1, 4, 3)
    for k in range(3):
        t = 0.25 + 0.28 * k
        bx = j[0] + (e[0] - j[0]) * t
        by = j[1] + (e[1] - j[1]) * t
        px, py = bx, by
        ang = rng.uniform(-2.5, -0.6)  # roots burst upward / backward
        for step in range(3):
            nxp = px + math.cos(ang) * 3 + rng.uniform(-1, 1)
            nyp = py + math.sin(ang) * 3 + rng.uniform(-1, 1)
            d.line([ipt((px, py)), ipt((nxp, nyp))], fill=C["root"], width=1)
            px, py = nxp, nyp
            ang += rng.uniform(-0.7, 0.7)
        if k == 1:
            d.point(ipt((px, py)), fill=C["cyan"])
            d.point(ipt((bx, by)), fill=C["cyan_d"])

    # ── post: necrotic mottling on flesh ──
    px_ = img.load()
    for y in range(H):
        for x in range(W):
            if px_[x, y] == C["flesh_m"]:
                r = (x * 73856093 ^ y * 19349663 ^ i * 83492791 ^ len(anim) * 2654435) % 100
                if r < 11:
                    px_[x, y] = C["flesh_d"]
                elif r > 92:
                    px_[x, y] = C["flesh_l"]
                elif r == 50:
                    px_[x, y] = C["rust_d"]  # patches of exposed corroded metal

    # ── post: 1px outline ──
    src = img.copy().load()
    for y in range(H):
        for x in range(W):
            if src[x, y][3] == 0:
                for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + ddx, y + ddy
                    if 0 <= xx < W and 0 <= yy < H and src[xx, yy][3] > 0:
                        px_[x, y] = C["outline"]
                        break
    return img


# ── output ──────────────────────────────────────────────────────────────────
def write_tres(frames_meta):
    lines = []
    ext = []
    n = 0
    anim_blocks = []
    for name, (count, fps, loop) in frames_meta.items():
        fr = []
        for i in range(count):
            n += 1
            rid = f"{n}_{name}{i}"
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/mrak/{name}_{i}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        anim_blocks.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
            % (", ".join(fr), "true" if loop else "false", name, fps)
        )
    lines.append(f"[gd_resource type=\"SpriteFrames\" load_steps={n + 1} format=3]")
    lines.append("")
    lines.extend(ext)
    lines.append("")
    lines.append("[resource]")
    lines.append("animations = [" + ", ".join(anim_blocks) + "]")
    lines.append("")
    with open(os.path.join(OUT, "mrak_frames.tres"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main():
    os.makedirs(OUT, exist_ok=True)
    scale = 4
    cols = max(c for c, _, _ in ANIMS.values())
    sheet = Image.new("RGBA", (cols * W * scale, len(ANIMS) * H * scale), (24, 24, 32, 255))
    sd = ImageDraw.Draw(sheet)
    for row, (name, (count, _fps, _loop)) in enumerate(ANIMS.items()):
        for i in range(count):
            fr = render(name, i)
            fr.save(os.path.join(OUT, f"{name}_{i}.png"))
            big = fr.resize((W * scale, H * scale), Image.NEAREST)
            ox, oy = i * W * scale, row * H * scale
            sd.rectangle([ox, oy, ox + W * scale - 1, oy + H * scale - 1], outline=(40, 40, 52, 255))
            sd.line([(ox, oy + 62 * scale), (ox + W * scale, oy + 62 * scale)], fill=(60, 60, 76, 255))
            sheet.alpha_composite(big, (ox, oy))
        sd.text((4, row * H * scale + 4), name, fill=(200, 200, 210, 255))
    sheet.convert("RGB").save(os.path.join(OUT, "_contact_sheet.png"))
    write_tres(ANIMS)
    total = sum(c for c, _, _ in ANIMS.values())
    print(f"OK: {total} frames -> {OUT}")


if __name__ == "__main__":
    main()
