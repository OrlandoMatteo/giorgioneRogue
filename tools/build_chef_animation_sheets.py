from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
FRAME_SIZE = 128


def load_frames(filename: str) -> list[Image.Image]:
    sheet = Image.open(SPRITES / filename).convert("RGBA")
    return [
        sheet.crop((index * FRAME_SIZE, 0, (index + 1) * FRAME_SIZE, FRAME_SIZE))
        for index in range(sheet.width // FRAME_SIZE)
    ]


def shifted(source: Image.Image, offset_x: int, offset_y: int) -> Image.Image:
    frame = Image.new("RGBA", (FRAME_SIZE, FRAME_SIZE), (0, 0, 0, 0))
    frame.alpha_composite(source, (offset_x, offset_y))
    return frame


def expand_to_eight(source_frames: list[Image.Image], transitions: list[tuple[int, int]]) -> list[Image.Image]:
    frames: list[Image.Image] = []
    for source, (offset_x, offset_y) in zip(source_frames, transitions):
        frames.append(source)
        frames.append(shifted(source, offset_x, offset_y))
    return frames


def save_sheet(frames: list[Image.Image], filename: str) -> None:
    sheet = Image.new("RGBA", (FRAME_SIZE * len(frames), FRAME_SIZE), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * FRAME_SIZE, 0))
    sheet.save(SPRITES / filename, optimize=True)


def main() -> None:
    walk_source = load_frames("chef_idle_v2.png")
    attack_source = load_frames("chef_attack_butter_v1.png")

    # Intermediate one-pixel poses preserve the chunky source art while
    # doubling each cycle from four to eight frames.
    walk = expand_to_eight(walk_source, [(0, -1), (1, -1), (0, 1), (-1, 1)])
    attack = expand_to_eight(attack_source, [(0, -1), (1, 0), (1, -1), (0, 1)])

    save_sheet(walk, "chef_walk_v3.png")
    save_sheet(attack, "chef_attack_butter_v2.png")


if __name__ == "__main__":
    main()
