from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
FRAME_SIZE = 128


def frame_from_sheet(filename: str, frame_index: int) -> Image.Image:
    sheet = Image.open(SPRITES / filename).convert("RGBA")
    left = frame_index * FRAME_SIZE
    return sheet.crop((left, 0, left + FRAME_SIZE, FRAME_SIZE))


def place_transformed(
    source: Image.Image,
    angle: float,
    offset_x: int,
    offset_y: int,
    pivot: tuple[int, int] = (64, 94),
) -> Image.Image:
    transformed = source.rotate(
        angle,
        resample=Image.Resampling.NEAREST,
        center=pivot,
        fillcolor=(0, 0, 0, 0),
    )
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    frame.alpha_composite(transformed, (offset_x, offset_y))
    return frame


def build_walk(source: Image.Image) -> list[Image.Image]:
    # A complete eight-frame step cycle. The one-pixel changes preserve the
    # chunky pixel-art edge while making movement read more smoothly in-game.
    angles = (0.0, -1.0, -2.0, -1.0, 0.0, 1.0, 2.0, 1.0)
    x_offsets = (0, -1, -2, -1, 0, 1, 2, 1)
    y_offsets = (0, -1, -2, -1, 0, -1, -2, -1)
    return [
        place_transformed(source, angle, x, y)
        for angle, x, y in zip(angles, x_offsets, y_offsets)
    ]


def build_death(source: Image.Image) -> list[Image.Image]:
    # Keep one canonical drawing throughout the fall so the character, skin
    # colour and protest sign cannot change between death frames.
    angles = (0.0, -7.0, -16.0, -28.0, -42.0, -58.0, -74.0, -88.0)
    x_offsets = (0, 0, 1, 2, 4, 6, 8, 10)
    y_offsets = (0, 2, 5, 9, 14, 20, 27, 34)
    alpha = (255, 255, 255, 255, 245, 230, 205, 175)
    frames: list[Image.Image] = []
    for angle, x, y, opacity in zip(angles, x_offsets, y_offsets, alpha):
        frame = place_transformed(source, angle, x, y)
        if opacity != 255:
            frame.putalpha(ImageEnhance.Brightness(frame.getchannel("A")).enhance(opacity / 255.0))
        frames.append(frame)
    return frames


def save_sheet(frames: list[Image.Image], filename: str) -> None:
    sheet = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * FRAME_SIZE, 0))
    sheet.save(SPRITES / filename, optimize=True)


def main() -> None:
    # Select one internally consistent source drawing for every enemy.
    # Turista frame 0 has the intended dark skin; the vegan frame uses the
    # unambiguous NO MEAT sign; the inspector frame retains his glasses.
    canonical = {
        "turista": frame_from_sheet("enemy_turista_walk_v2.png", 0),
        "ladro": frame_from_sheet("enemy_ladro_walk_v2.png", 2),
        "ispettore": frame_from_sheet("enemy_ispettore_walk_v2.png", 0),
    }

    versions = {
        "turista": ("enemy_turista_walk_v3.png", "enemy_turista_death_v2.png"),
        "ladro": ("enemy_ladro_walk_v3.png", "enemy_ladro_death_v2.png"),
        "ispettore": ("enemy_ispettore_walk_v3.png", "enemy_ispettore_death_v2.png"),
    }
    for enemy_id, source in canonical.items():
        walk_name, death_name = versions[enemy_id]
        save_sheet(build_walk(source), walk_name)
        save_sheet(build_death(source), death_name)


if __name__ == "__main__":
    main()
