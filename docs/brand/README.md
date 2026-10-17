# Logo

`briani-logo.png` is the master logo: the pot mark over the "Briani Player" wordmark, on a transparent background. Every other logo image in the repository is rendered from it:

| Output | Used for |
|---|---|
| `client/assets/brand/logo.png` | Full logo on the server list screen |
| `client/assets/brand/mark.png` | Pot mark in the desktop navigation rail and the TV top bar |
| `client/assets/brand/app_icon.png` | Linux window icon |
| `client/android/.../mipmap-*/ic_launcher_{foreground,monochrome}.png` | Android adaptive and themed launcher icon (white background) |
| `client/android/.../drawable-xhdpi/tv_banner.png` | Android TV home banner |
| `client/macos/.../AppIcon.appiconset/app_icon_*.png` | macOS app icon |
| `client/windows/runner/resources/app_icon.ico` | Windows app icon |
| `infra/downloads/page.html` (inline) | Download page favicon and header mark |

After replacing the master, regenerate everything (needs Pillow; uses `zopflipng` when installed):

```sh
python3 tools/brand/render_brand_assets.py
```

The logo keeps its own colors. The app and download page palettes do not follow it.
