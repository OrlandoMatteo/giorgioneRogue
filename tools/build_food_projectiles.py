from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
FRAME_SIZE = 64


def frittata_base() -> Image.Image:
    image = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.ellipse((10, 10, 54, 54), fill="#3a2114")
    draw.ellipse((13, 13, 51, 51), fill="#b96a28")
    draw.ellipse((16, 16, 48, 48), fill="#f2c84b")
    draw.rectangle((21, 21, 27, 26), fill="#fff0a1")
    draw.rectangle((37, 32, 43, 38), fill="#d34a2f")
    draw.rectangle((27, 39, 33, 44), fill="#5d8b35")
    draw.rectangle((33, 19, 38, 24), fill="#e99432")
    return image


def bruschetta_base() -> Image.Image:
    image = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    outline = [(8, 19), (20, 10), (53, 17), (55, 44), (43, 54), (12, 48)]
    crust = [(11, 20), (21, 13), (50, 19), (52, 42), (41, 51), (14, 45)]
    crumb = [(16, 21), (23, 17), (47, 22), (48, 39), (39, 46), (17, 42)]
    draw.polygon(outline, fill="#382116")
    draw.polygon(crust, fill="#a95b2d")
    draw.polygon(crumb, fill="#edbd68")
    draw.rectangle((21, 22, 43, 28), fill="#a93626")
    draw.rectangle((18, 31, 46, 38), fill="#c84a2d")
    draw.rectangle((27, 25, 33, 31), fill="#f4df91")
    draw.rectangle((38, 34, 44, 39), fill="#f7e3a0")
    draw.rectangle((20, 36, 25, 41), fill="#4f7b32")
    return image


def rotating_sheet(base: Image.Image) -> Image.Image:
    sheet = Image.new("RGBA", (FRAME_SIZE * 4, FRAME_SIZE), (0, 0, 0, 0))
    for index, angle in enumerate((0, -45, -90, -135)):
        frame = base.rotate(
            angle,
            resample=Image.Resampling.NEAREST,
            center=(FRAME_SIZE // 2, FRAME_SIZE // 2),
            fillcolor=(0, 0, 0, 0),
        )
        sheet.alpha_composite(frame, (index * FRAME_SIZE, 0))
    return sheet


def main() -> None:
    rotating_sheet(frittata_base()).save(SPRITES / "frittata_projectile_v1.png", optimize=True)
    rotating_sheet(bruschetta_base()).save(SPRITES / "bruschetta_projectile_v1.png", optimize=True)


if __name__ == "__main__":
    main()
