import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

def create_high_energy_logo():
    # Supersampling canvas: 1024x1024 rendered down to 512x512
    W, H = 1024, 1024
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Palette
    forest_dark = (33, 64, 43, 255)       # #21402B deep obsidian forest
    forest_mid = (42, 78, 53, 255)        # #2A4E35 primary forest
    sage_accent = (168, 212, 175, 255)    # #A8D4AF soft sage mint
    coral_orange = (255, 110, 77, 255)    # #FF6E4D vivid coral
    amber_gold = (255, 175, 45, 255)      # #FFAF2D warm amber
    electric_yellow = (255, 218, 50, 255) # #FFDA32 electric lightning
    spark_white = (255, 255, 255, 240)

    center_x = 520
    center_y = 512

    # --- 1. Background Motion Speed Lines & Chevrons ---
    # Velocity streaks trailing to the left
    streaks = [
        # (x1, y1, x2, y2, width, color)
        (140, 360, 310, 360, 16, (210, 232, 212, 200)),
        (100, 440, 280, 440, 24, (255, 175, 45, 180)),
        (80, 520, 250, 520, 32, (255, 110, 77, 220)),
        (120, 600, 300, 600, 20, (42, 78, 53, 190)),
        (160, 680, 340, 680, 14, (210, 232, 212, 180)),
        # Forward speed spikes to the right
        (760, 320, 890, 320, 14, (255, 175, 45, 210)),
        (810, 400, 940, 400, 22, (255, 110, 77, 230)),
        (780, 480, 910, 480, 18, (255, 218, 50, 220)),
        (740, 640, 870, 640, 16, (42, 78, 53, 170)),
    ]

    for x1, y1, x2, y2, stroke, col in streaks:
        draw.line([(x1, y1), (x2, y2)], fill=col, width=stroke)
        # Rounded caps
        r = stroke / 2.0
        draw.ellipse([x1 - r, y1 - r, x1 + r, y1 + r], fill=col)
        draw.ellipse([x2 - r, y2 - r, x2 + r, y2 + r], fill=col)

    # Motion Chevrons (» » »)
    def draw_chevron(cx, cy, size, col, stroke=14):
        p1 = (cx - size, cy - size * 0.9)
        p2 = (cx, cy)
        p3 = (cx - size, cy + size * 0.9)
        draw.line([p1, p2, p3], fill=col, width=stroke, joint="curve")

    draw_chevron(730, 260, 26, (255, 110, 77, 230), stroke=16)
    draw_chevron(790, 260, 26, (255, 175, 45, 230), stroke=16)
    draw_chevron(260, 760, 22, (42, 78, 53, 200), stroke=14)
    draw_chevron(320, 760, 22, (168, 212, 175, 220), stroke=14)

    # --- 2. Dynamic Greek Letter "A" (Angled forward by ~15°) ---
    # Left Wing of "A" (Solid Forest with forward slant)
    # Apex at (500, 180), Left base at (280, 820)
    left_leg = [
        (480, 180),  # Top apex
        (540, 180),
        (380, 820),  # Base inner
        (260, 820),  # Base outer
    ]
    draw.polygon(left_leg, fill=forest_dark)

    # Inner highlight on Left Wing
    left_highlight = [
        (495, 210),
        (530, 210),
        (405, 780),
        (370, 780),
    ]
    draw.polygon(left_highlight, fill=forest_mid)

    # Right Wing of "A" (slanted back down to (750, 820))
    right_leg = [
        (500, 180),
        (570, 180),
        (760, 820),
        (650, 820),
    ]
    draw.polygon(right_leg, fill=forest_mid)

    # Horizontal Crossbar of "A" (Velocity bridge)
    crossbar = [
        (355, 540),
        (660, 540),
        (680, 610),
        (335, 610),
    ]
    draw.polygon(crossbar, fill=forest_dark)

    # --- 3. Electric Lightning Bolt (⚡) Fused Right Through The "A" ---
    # The bolt cuts diagonally from upper right (680, 130) through center to lower left/center (460, 890)
    # Upper spike -> Center zigzag -> Lower dynamic arrowhead
    bolt_outer = [
        (690, 120),  # Top tip
        (550, 420),  # Inner bend top
        (650, 410),  # Middle flare
        (450, 900),  # Bottom needle tip
        (530, 560),  # Inner bend bottom
        (430, 570),  # Outer flare
    ]
    # Draw warm amber shadow/bevel
    bolt_shadow = [(x + 8, y + 10) for (x, y) in bolt_outer]
    draw.polygon(bolt_shadow, fill=(180, 50, 10, 160))

    # Coral Orange Core
    draw.polygon(bolt_outer, fill=coral_orange)

    # Inner Electric Yellow Bevel
    bolt_inner = [
        (680, 150),
        (560, 410),
        (630, 410),
        (465, 860),
        (525, 575),
        (450, 575),
    ]
    draw.polygon(bolt_inner, fill=amber_gold)

    # Bright Center Lightning Core
    bolt_core = [
        (670, 180),
        (570, 400),
        (610, 400),
        (480, 820),
        (520, 590),
        (470, 590),
    ]
    draw.polygon(bolt_core, fill=electric_yellow)

    # Intense white center spark line
    draw.line([(660, 200), (580, 390)], fill=spark_white, width=8)
    draw.line([(580, 390), (600, 390)], fill=spark_white, width=8)
    draw.line([(600, 390), (490, 780)], fill=spark_white, width=8)

    # Small electric sparks & dots around the impact zone
    sparks = [
        (680, 350, 10, electric_yellow),
        (720, 420, 14, coral_orange),
        (410, 670, 12, electric_yellow),
        (380, 480, 16, amber_gold),
        (560, 280, 8, spark_white),
        (430, 840, 10, coral_orange),
    ]
    for sx, sy, sr, scol in sparks:
        draw.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=scol)

    # Return high-resolution emblem
    return img

def render_ceramic_squircle(emblem_img, size=512, corner_radius=110):
    # Create squircle canvas with ceramic background #FBFBF6
    W, H = size, size
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("L", (W, H), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, W, H], radius=corner_radius, fill=255)

    # Ceramic background fill
    bg = Image.new("RGBA", (W, H), (251, 251, 246, 255)) # #FBFBF6

    # Resize emblem down to fit inside squircle with breathing room (padding ~15%)
    emblem_resized = emblem_img.resize((int(size * 0.82), int(size * 0.82)), Image.Resampling.LANCZOS)
    offset_x = (size - emblem_resized.width) // 2
    offset_y = (size - emblem_resized.height) // 2

    bg.paste(emblem_resized, (offset_x, offset_y), emblem_resized)
    canvas.paste(bg, (0, 0), mask)
    return canvas

def render_circle_icon(emblem_img, size=512):
    W, H = size, size
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("L", (W, H), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse([0, 0, W, H], fill=255)

    bg = Image.new("RGBA", (W, H), (251, 251, 246, 255))
    emblem_resized = emblem_img.resize((int(size * 0.72), int(size * 0.72)), Image.Resampling.LANCZOS)
    offset_x = (size - emblem_resized.width) // 2
    offset_y = (size - emblem_resized.height) // 2

    bg.paste(emblem_resized, (offset_x, offset_y), emblem_resized)
    canvas.paste(bg, (0, 0), mask)
    return canvas

def render_adaptive_foreground(emblem_img, size=432):
    # Android adaptive foreground: emblem centered in 66% safe zone
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    emblem_size = int(size * 0.62)
    emblem_resized = emblem_img.resize((emblem_size, emblem_size), Image.Resampling.LANCZOS)
    offset_x = (size - emblem_resized.width) // 2
    offset_y = (size - emblem_resized.height) // 2
    canvas.paste(emblem_resized, (offset_x, offset_y), emblem_resized)
    return canvas

def main():
    print("Generating high-energy Areté logo (velocity 'A' + ⚡ lightning bolt)...")
    emblem = create_high_energy_logo()

    # 1. Save transparent 512x512 emblem
    emblem_512 = emblem.resize((512, 512), Image.Resampling.LANCZOS)
    os.makedirs("assets/images", exist_ok=True)
    emblem_512.save("assets/images/logo_emblem.png", "PNG")
    print("Saved assets/images/logo_emblem.png")

    # 2. Save ceramic 512x512 squircle icon
    logo_512 = render_ceramic_squircle(emblem, size=512, corner_radius=115)
    logo_512.save("assets/images/logo.png", "PNG")
    print("Saved assets/images/logo.png")

    # 3. Save square card format
    square_card = Image.new("RGBA", (512, 512), (251, 251, 246, 255))
    emblem_card = emblem.resize((int(512 * 0.82), int(512 * 0.82)), Image.Resampling.LANCZOS)
    square_card.paste(emblem_card, ((512 - emblem_card.width) // 2, (512 - emblem_card.height) // 2), emblem_card)
    square_card.save("assets/images/logo_square.png", "PNG")
    print("Saved assets/images/logo_square.png")

    # 4. Save splash_icon.png for native Android splash
    splash_icon = emblem.resize((288, 288), Image.Resampling.LANCZOS)
    splash_icon.save("android/app/src/main/res/drawable/splash_icon.png", "PNG")
    print("Saved android/app/src/main/res/drawable/splash_icon.png")

    # 5. Save launcher mipmaps
    densities = {
        "mdpi": (48, 108),
        "hdpi": (72, 162),
        "xhdpi": (96, 216),
        "xxhdpi": (144, 324),
        "xxxhdpi": (192, 432),
    }

    for dens, (sq_size, fg_size) in densities.items():
        dir_path = f"android/app/src/main/res/mipmap-{dens}"
        os.makedirs(dir_path, exist_ok=True)

        radius = int(sq_size * 0.22)
        sq_icon = render_ceramic_squircle(emblem, size=sq_size, corner_radius=radius)
        sq_icon.save(os.path.join(dir_path, "ic_launcher.png"), "PNG")

        round_icon = render_circle_icon(emblem, size=sq_size)
        round_icon.save(os.path.join(dir_path, "ic_launcher_round.png"), "PNG")

        fg_icon = render_adaptive_foreground(emblem, size=fg_size)
        fg_icon.save(os.path.join(dir_path, "ic_launcher_foreground.png"), "PNG")
        print(f"Generated {dens} icons in {dir_path}")

    print("High-energy brand logo assets created successfully!")

if __name__ == "__main__":
    main()
