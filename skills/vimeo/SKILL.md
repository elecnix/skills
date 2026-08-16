---
name: vimeo
description: Download videos from Vimeo (including private/unlisted hash links) with yt-dlp. Use when asked to download a Vimeo video, when yt-dlp fails with "Failed to fetch macos OAuth token", "only works when logged-in", or Cloudflare Turnstile errors, or when Vimeo videos must be saved locally. Requires the user's Vimeo login (free account) via Chrome cookies.
license: MIT
metadata:
  author: elecnix
  version: "1.0"
---

# Vimeo Downloads

Download Vimeo videos — including **private/unlisted** links like `https://vimeo.com/123456789/abcdef1abc` (placeholder ID/hash) — at maximum quality using yt-dlp with an authenticated session.

> **Why authentication?** Since mid-2026, Vimeo blocks anonymous downloads: the web client is behind a Cloudflare **Turnstile** bot challenge and yt-dlp refuses to extract without login (`The Vimeo extractor only works when logged-in`). A **free** Vimeo account is required, and cookies must come from a real logged-in browser session.

## Prerequisites

- **yt-dlp 2026.08+** (use the latest nightly: `curl -L -o /usr/local/bin/yt-dlp https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/latest/download/yt-dlp && chmod +x /usr/local/bin/yt-dlp`)
- **ffmpeg** (for merging video+audio: `sudo apt install ffmpeg`)
- A Vimeo account (free tier is enough) logged in in Chrome
- For Chrome cookie decryption on Linux: `sudo apt install python3-secretstorage` (needed when using `--cookies-from-browser`)
- Node.js 22+ (only for the CDP cookie-export helper)

## Workflow

### Step 1: Verify the URLs

Private links work in yt-dlp as-is — the hash token grants access:

```bash
yt-dlp -F "https://vimeo.com/123456789/abcdef1abc"   # lists available formats (use the real ID/hash)
```

Do NOT strip the hash suffix. Check available resolutions first (`-F`): Vimeo shows HLS variants, sometimes up to 4K. Note that sizes vary wildly (74 MB to 1+ GB per video).

### Step 2: Get cookies from the logged-in session

Two options, in order:

**Option A — direct from Chrome (fastest):**

```bash
yt-dlp --cookies-from-browser chrome -F "https://vimeo.com/<id>/<hash>"
```

If you get `secretstorage not available` or `failed to decrypt cookie`, install `python3-secretstorage` and retry. If the user is not logged into Vimeo in Chrome, or the session cookie is not readable, use Option B.

**Option B — CDP cookie export (fallback):**

With the [chrome-cdp skill](https://github.com/pasky/chrome-cdp-skill) pattern: open `https://vimeo.com` in a new Chrome tab, ask the user to log in, then export:

```bash
node skills/vimeo/get-vimeo-cookies.mjs /tmp/vimeo_cookies.txt
```

The helper finds Chrome's debugging port (`DevToolsActivePort`), grabs a Vimeo tab, dumps **all** cookies (including httpOnly) via `Network.getAllCookies`, and writes a Netscape-format file. Confirm the output says `Logged in: true`.

### Step 3: Download

```bash
yt-dlp --cookies /tmp/vimeo_cookies.txt \
  -f "bestvideo+bestaudio/best" \
  --merge-output-format mp4 \
  -o "MyShow_gr1.mp4" \
  "https://vimeo.com/<id>/<hash>"
```

Batch many videos: run them sequentially in a script (see **Batch tip**). Progress is slow per video (~1–3 min each); don't set aggressive timeouts.

## Batch tip

When the same video must appear in several folders (e.g. the same recording listed under two show dates), download **once** and **hardlink** the rest — instant and zero extra disk:

```bash
ln "Folder A/Show_gr1.mp4" "Folder B/Show_gr1.mp4"
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Failed to fetch macos OAuth token: HTTP Error 401` | Update yt-dlp to the latest **nightly** — old releases cannot authenticate |
| `The Vimeo extractor only works when logged-in` | No valid session cookies — use Option A/B and confirm `is_logged_in` |
| `secretstorage not available` / `failed to decrypt cookie` | `sudo apt install python3-secretstorage` |
| Turnstile / "Sorry" page on direct `curl` | Expected — Vimeo only serves the player to real browsers; use yt-dlp with cookies, never curl |
| `invalid Netscape format cookies file` / `AssertionError` | Keep the **leading dot** on subdomain cookies (`.vimeo.com`) and `TRUE` in the includeSubdomains column — the helper script already does this |
| Download stuck at very low speed | Normal on the first fragments (manifest + key fetch); it ramps up. Don't abort early |

## Notes

- **No secrets in the skill:** cookies are session data, never committed anywhere.
- Videos downloaded are for personal archiving of content the user has access to.
- If the user isn't logged into Vimeo, ask them to log in (free account) in Chrome before running the download.
