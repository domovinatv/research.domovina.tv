# Research — DOMOVINA.tv

Encrypted bilingual (EN/HR) research document viewer. Content is AES-256 encrypted at rest and decrypted client-side with a passphrase — safe to host on a public repository.

## Live

- **https://research.domovina.tv** — GitHub Pages (CanvasKit)
- **https://ultra.research.domovina.tv** — Cloudflare Pages (WASM)

## How it works

1. Markdown documents are encrypted offline with AES-256-CBC
2. Encrypted `.enc` files are bundled as Flutter assets
3. On load, the user enters a passphrase to decrypt in-browser
4. Content is displayed in a side-by-side bilingual viewer with chapter navigation

No plaintext content is stored in this repository or transmitted to any server.

## Encryption

Plaintext sources (`mhs-001.en.md`, `mhs-001.hr.md`) are gitignored. After editing, re-encrypt:

```
dart run tool/encrypt_assets.dart <passphrase>
```

## Build & deploy

### GitHub Pages

```bash
flutter build web --release
rm -rf docs && cp -R build/web docs
git add docs && git commit -m "deploy: update GitHub Pages build"
git push origin main
```

### Cloudflare Pages (WASM)

```bash
flutter build web --wasm --release
CLOUDFLARE_ACCOUNT_ID=7dc7167b7e2e00923bfa7cd697df14e4 \
  npx wrangler pages deploy build/web --project-name ultra-research-domovina-tv
```

## Tech stack

- Flutter web (Dart)
- `flutter_markdown` — markdown rendering
- `encrypt` + `crypto` — AES-256-CBC decryption
- `google_fonts` — Inter typeface
