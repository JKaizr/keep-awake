"""Renders the DMG window background (1x + 2x).
Window 640×420 pt. Finder places the icons at (160,200) and (480,200), see make-dmg.sh.
Run:  python3 dmg/make_background.py   (needs cairosvg; uses the Inter font)
"""
import pathlib
import cairosvg

HERE = pathlib.Path(__file__).parent

SVG = """
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="420" viewBox="0 0 640 420">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="420" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#F4F5FA"/>
      <stop offset="1" stop-color="#E4E7F2"/>
    </linearGradient>
    <linearGradient id="arrow" x1="250" y1="0" x2="390" y2="0" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#2B3A78" stop-opacity="0.25"/>
      <stop offset="1" stop-color="#2B3A78" stop-opacity="0.75"/>
    </linearGradient>
  </defs>
  <rect width="640" height="420" fill="url(#bg)"/>

  <text x="320" y="62" text-anchor="middle" font-family="Inter Display, Inter" font-weight="700"
        font-size="26" fill="#1D2450">Awake</text>
  <text x="320" y="88" text-anchor="middle" font-family="Inter" font-size="13" fill="#5A6185">
    Mac zůstane vzhůru přesně tak dlouho, jak potřebuješ.</text>

  <!-- arrow between the two icon slots -->
  <path d="M 252 200 L 372 200" stroke="url(#arrow)" stroke-width="6" stroke-linecap="round"/>
  <path d="M 362 186 L 386 200 L 362 214" fill="none" stroke="#2B3A78" stroke-opacity="0.75"
        stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>

  <text x="320" y="322" text-anchor="middle" font-family="Inter" font-weight="600" font-size="14"
        fill="#1D2450">Přetáhni Awake do složky Aplikace</text>
  <text x="320" y="356" text-anchor="middle" font-family="Inter" font-size="11.5" fill="#6A7093">
    Při prvním spuštění: Nastavení systému → Soukromí a zabezpečení → Přesto otevřít</text>
  <text x="320" y="374" text-anchor="middle" font-family="Inter" font-size="11.5" fill="#6A7093">
    Awake pak najdeš v menu baru (ikona šálku), ne v Docku.</text>
</svg>
"""

for scale, name in [(1, "background.png"), (2, "background@2x.png")]:
    cairosvg.svg2png(bytestring=SVG.encode(), write_to=str(HERE / name),
                     output_width=640 * scale, output_height=420 * scale)
    print("wrote", HERE / name)
