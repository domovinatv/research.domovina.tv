# CLAUDE.md — Project context for Claude Code

## Project overview
Flutter web/iPad app — encrypted bilingual (EN/HR) research document viewer for DOMOVINA.tv.
Content is AES-256-CBC encrypted; user enters a passphrase to decrypt and view side-by-side markdown.

## Key files
- `lib/main.dart` — entire app (unlock screen, dual markdown viewer, chapter navigation)
- `tool/encrypt_assets.dart` — CLI to encrypt markdown files into `assets/*.enc`
- `assets/<doc-id>.en.enc`, `assets/<doc-id>.hr.enc` — encrypted content pairs
- `<doc-id>.en.md`, `<doc-id>.hr.md` — plaintext source (gitignored, never commit)
- Current document pairs: `mhs-001` (main research), `sample` (demo/test)
- `web/index.html` — HTML shell with OG/social meta tags
- `build/web/_headers` — Cloudflare Pages COOP/COEP headers for WASM

## Encryption
Each document pair has its own passphrase (shared separately, not stored in repo).
Encrypt after editing markdown sources:
```
dart run tool/encrypt_assets.dart <doc-id> <passphrase>
```
Example: `dart run tool/encrypt_assets.dart mhs-001 my-secret-key`
Format: `base64(IV[16 bytes] + ciphertext)`, plaintext prefixed with `MHS_OK:` marker.

## Build & deploy

### GitHub Pages (standard CanvasKit build)
Served from `main` branch `/docs` folder at research.domovina.tv.
```bash
flutter build web --release
rm -rf docs && cp -R build/web docs
git add docs && git commit -m "deploy: update GitHub Pages build"
git push origin main
```

### Cloudflare Pages (WASM/Skwasm build)
Project: `ultra-research-domovina-tv` on account `7dc7167b7e2e00923bfa7cd697df14e4` (D.O.M.).
Custom domain: `ultra.research.domovina.tv`.
WASM requires COOP/COEP headers — the `_headers` file in `build/web/` handles this.
```bash
flutter build web --wasm --release
# _headers file is in web/ and gets copied to build/web/ automatically
CLOUDFLARE_ACCOUNT_ID=7dc7167b7e2e00923bfa7cd697df14e4 \
  npx wrangler pages deploy build/web --project-name ultra-research-domovina-tv
```

### Full rebuild + deploy both
```bash
# 1. Build WASM for Cloudflare
flutter build web --wasm --release
CLOUDFLARE_ACCOUNT_ID=7dc7167b7e2e00923bfa7cd697df14e4 \
  npx wrangler pages deploy build/web --project-name ultra-research-domovina-tv

# 2. Build standard for GitHub Pages
flutter build web --release
rm -rf docs && cp -R build/web docs
git add docs && git commit -m "deploy: update web builds"
git push origin main
```

## iPad deployment
Device ID: `00008101-000405A80E0A601E`. Team ID: `GQX28TWCRN`.
```bash
flutter run -d 00008101-000405A80E0A601E
```

## Git conventions
- Semantic commit messages (`feat:`, `fix:`, `deploy:`, etc.)
- Plaintext `.md` files are in `.gitignore` — only encrypted `.enc` files are committed
- Remote: `git@github.com:domovinatv/research.domovina.tv.git`
