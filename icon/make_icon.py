"""Renders the Awake app icon (night sky + warm coffee cup) and builds AppIcon.icns.

Run:  python3 icon/make_icon.py
Needs: pip install cairosvg pillow
"""
import io
import pathlib

import cairosvg
from PIL import Image, ImageFilter

HERE = pathlib.Path(__file__).parent
OUT_ICNS = HERE.parent / "Awake" / "AppIcon.icns"
OUT_PNG = HERE / "AppIcon-1024.png"

# Apple macOS icon grid: 1024 canvas, 824 body, 100 margin.
SVG = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="sky" x1="0" y1="100" x2="0" y2="924" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#34449A"/>
      <stop offset="0.55" stop-color="#1F2A63"/>
      <stop offset="1" stop-color="#121838"/>
    </linearGradient>
    <radialGradient id="glow" cx="500" cy="610" r="380" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFB25C" stop-opacity="0.55"/>
      <stop offset="0.55" stop-color="#FF8A3D" stop-opacity="0.2"/>
      <stop offset="1" stop-color="#FF8A3D" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="sheen" x1="0" y1="100" x2="0" y2="520" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.16"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="porcelain" x1="290" y1="0" x2="690" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="0.6" stop-color="#F6EDE2"/>
      <stop offset="1" stop-color="#DCCBB8"/>
    </linearGradient>
    <linearGradient id="saucer" x1="0" y1="770" x2="0" y2="860" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#F7EFE6"/>
      <stop offset="1" stop-color="#CDBBA7"/>
    </linearGradient>
    <radialGradient id="coffee" cx="470" cy="470" r="210" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#8A5128"/>
      <stop offset="1" stop-color="#3E2210"/>
    </radialGradient>
    <linearGradient id="steam" x1="0" y1="440" x2="0" y2="215" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.95"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <clipPath id="body"><rect x="100" y="100" width="824" height="824" rx="186"/></clipPath>
  </defs>

  <g clip-path="url(#body)">
    <rect x="100" y="100" width="824" height="824" fill="url(#sky)"/>
    <rect x="100" y="100" width="824" height="824" fill="url(#glow)"/>
    <rect x="100" y="100" width="824" height="420" fill="url(#sheen)"/>

    <!-- stars -->
    <g fill="#FFFFFF">
      <circle cx="232" cy="236" r="7" opacity="0.85"/>
      <circle cx="318" cy="168" r="4.5" opacity="0.6"/>
      <circle cx="772" cy="210" r="6" opacity="0.8"/>
      <circle cx="842" cy="318" r="4" opacity="0.55"/>
      <circle cx="680" cy="150" r="3.5" opacity="0.5"/>
      <circle cx="178" cy="392" r="4" opacity="0.45"/>
    </g>
    <!-- crescent moon -->
    <path d="M 800.2 166.5 A 60 60 0 1 0 863.5 248.8 A 52 52 0 1 1 800.2 166.5 Z" fill="#FFE7B8" opacity="0.9"/>

    <!-- saucer -->
    <ellipse cx="490" cy="822" rx="300" ry="54" fill="#0B0F24" opacity="0.35"/>
    <ellipse cx="490" cy="806" rx="292" ry="48" fill="url(#saucer)"/>
    <ellipse cx="490" cy="798" rx="200" ry="26" fill="#BBA894" opacity="0.55"/>

    <!-- handle (behind cup) -->
    <circle cx="694" cy="590" r="70" fill="none" stroke="#E4D5C4" stroke-width="44"/>

    <!-- cup -->
    <path d="M 290 480 L 690 480 C 690 640 650 760 556 792 L 424 792 C 330 760 290 640 290 480 Z"
          fill="url(#porcelain)"/>
    <path d="M 330 520 C 334 620 360 700 410 748" fill="none" stroke="#FFFFFF" stroke-width="18"
          stroke-linecap="round" opacity="0.7"/>
    <ellipse cx="490" cy="480" rx="200" ry="36" fill="#FFFDF9"/>
    <ellipse cx="490" cy="483" rx="176" ry="27" fill="url(#coffee)"/>
    <ellipse cx="450" cy="476" rx="60" ry="7" fill="#C8875A" opacity="0.45"/>

    <!-- steam -->
    <g fill="none" stroke="url(#steam)" stroke-width="30" stroke-linecap="round">
      <path d="M 412 432 C 382 392 442 362 412 318 C 392 288 418 262 414 238"/>
      <path d="M 492 438 C 462 394 522 360 492 312 C 470 278 500 246 496 220"/>
      <path d="M 572 432 C 542 392 602 362 572 318 C 552 288 578 262 574 238"/>
    </g>
  </g>

  <!-- hairline edge -->
  <rect x="100.5" y="100.5" width="823" height="823" rx="186" fill="none" stroke="#FFFFFF" stroke-opacity="0.12"/>
</svg>
"""


def render() -> Image.Image:
    png = cairosvg.svg2png(bytestring=SVG.encode(), output_width=2048, output_height=2048)
    art = Image.open(io.BytesIO(png)).convert("RGBA").resize((1024, 1024), Image.LANCZOS)

    # Soft drop shadow, like system icons.
    alpha = art.getchannel("A")
    shadow = Image.new("RGBA", art.size, (0, 0, 0, 0))
    shadow_mask = alpha.point(lambda a: int(a * 0.45))
    shadow.paste((0, 0, 0, 255), (0, 12), shadow_mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    return Image.alpha_composite(shadow, art)


def main() -> None:
    icon = render()
    icon.save(OUT_PNG)
    sizes = [(16, 16), (32, 32), (64, 64), (128, 128), (256, 256), (512, 512), (1024, 1024)]
    icon.save(OUT_ICNS, sizes=sizes)
    print(f"wrote {OUT_PNG} and {OUT_ICNS}")


if __name__ == "__main__":
    main()
