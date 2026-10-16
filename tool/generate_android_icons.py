"""Generate Android icons from the unchanged iOS master (requires Pillow)."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
RES = ROOT / "android/app/src/main/res"


def main():
    with Image.open(SOURCE) as source:
        for density, edge in [
            ("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
            ("xxhdpi", 144), ("xxxhdpi", 192),
        ]:
            source.resize((edge, edge), Image.Resampling.LANCZOS).save(
                RES / f"mipmap-{density}/ic_launcher.png"
            )

        # Adaptive launchers expose the central 72dp of a 108dp foreground.
        # Inset the iOS tile so the O retains its original size after that zoom.
        foreground = Image.new("RGBA", (432, 432), (255, 255, 255, 0))
        foreground.paste(source.resize((288, 288), Image.Resampling.LANCZOS), (72, 72))
        output = RES / "drawable-nodpi/ic_launcher_ios.png"
        output.parent.mkdir(exist_ok=True)
        foreground.save(output)


if __name__ == "__main__":
    main()
