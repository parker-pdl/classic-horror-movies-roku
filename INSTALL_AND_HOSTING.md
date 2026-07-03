# Classic Horror Movies by: ParkerDataLink.com — Roku Channel

A SceneGraph / BrightScript Roku channel with a Netflix-style browse experience,
in-channel video playback, and a **remote JSON feed** you can update anytime
without rebuilding the channel.

Built on top of your existing "Parker Data Link" project — same architecture,
refreshed UI, corrected assets, and a live catalogue of **105 public-domain
titles** across 6 rows (all streaming from the Internet Archive).

---

## What changed from your previous build

- **Channel renamed** to *Classic Horror Movies by: ParkerDataLink.com* (manifest).
- **Netflix-style HomeScreen** — atmospheric backdrop, a **spotlight hero** that
  updates as you browse, larger 2:3 poster cards that scale + glow on focus,
  and clean category rows.
- **Remote feed** — the channel now fetches its catalogue from a JSON feed you
  host (with a bundled copy as a fallback), instead of a hard-coded list. The
  old `MainScene.brs` had raw JSON pasted into the middle of the code and would
  not compile; that is fixed.
- **Verified catalogue** — every one of the 63 underlying Archive items was
  checked to exist, and each of the 100 stream URLs was rebuilt from your live
  site and URL-encoded so the Roku Video node can play them.
- **Icon/splash fixed** — your manifest pointed at `channel_icon_fhd.png`, but
  the real files had a trailing space in the name, so the icon never resolved.
  New, correctly-named, correctly-sized assets are generated from your hooded-
  figures "Parker Data Link" artwork.
- **5 public-domain classic shorts added** to the Short Horror row (Méliès's
  *Le Manoir du Diable* 1896 — the first horror film ever made — plus *The
  Infernal Cauldron* 1903, *The Monster* 1903, *Dr. Jekyll and Mr. Hyde* 1912,
  and Lois Weber's *Suspense* 1913).

> **Note on "recent" shorts:** genuine *public-domain* horror shorts from the
> last 30 years effectively don't exist — the Internet Archive's recent
> "public domain / CC0" tags are overwhelmingly mislabeled copyrighted uploads
> (studio Blu-ray rips, YouTube re-uploads, etc.). Per your call to stay
> strictly public domain, the additions above are all pre-1930 and unambiguously
> PD by age. If you ever want genuinely-recent shorts, the realistic legal route
> is Creative-Commons-licensed indie films shown with attribution — happy to add
> a "Modern Indie Shorts (CC-BY)" row on request.

---

## 1. Sideload it (test on your Roku)

1. **Enable Developer Mode** on your Roku: press
   `Home ×3, Up ×2, Right, Left, Right, Left, Right`. Note the IP address, set a
   dev password, accept the agreement.
2. In a browser go to `http://<ROKU_IP>`, log in as `rokudev` + your password.
3. Click **Upload**, choose `ClassicHorrorMovies.zip`, click **Install**.

Or via cURL:

```bash
curl -F "mysubmit=Install" -F "archive=@ClassicHorrorMovies.zip" \
     --user rokudev:<PASSWORD> --digest http://<ROKU_IP>/plugin_install
```

The channel ships with the full feed baked in, so it works immediately — even
before you host the remote feed below.

---

## 2. Host the feed so you can update content without re-sideloading

The channel fetches its catalogue from:

```
https://roku-feed.parkerdatalinktv.workers.dev/feed.json
```

(defined in `components/MainScene.brs` → `FEED_URL()` — change it there if you
prefer a different path).

Because your site is on **Cloudflare**, just publish `feed.json` at that path:

- **Cloudflare Pages** (static site): drop `feed.json` into a `roku/` folder in
  your project and redeploy, so it serves at `/roku/feed.json`.
- **Cloudflare R2 + custom domain / Worker**: upload `feed.json` and route
  `stream.parkerdatalink.com/roku/feed.json` to it.
- Make sure it's served with `Content-Type: application/json` and is publicly
  readable (no auth), so the Roku can fetch it.

After that, editing the catalogue is just editing `feed.json` and re-publishing —
no channel rebuild, no re-sideload. The channel re-reads the feed on every launch.

---

## 3. Feed format

```json
{
  "providerName": "Classic Horror Movies by: ParkerDataLink.com",
  "categories": [
    {
      "title": "Classic Horror",
      "items": [
        {
          "id": "night-of-the-living-dead-1968",
          "title": "Night of the Living Dead",
          "year": "1968",
          "description": "…",
          "poster": "https://archive.org/services/img/night-of-the-living-dead-1968",
          "streamUrl": "https://archive.org/download/night-of-the-living-dead-1968/Night%20of%20the%20Living%20Dead%20%281968%29.mp4",
          "streamFormat": "mp4"
        }
      ]
    }
  ]
}
```

Rules that matter for Roku:
- `streamUrl` must be a **direct** MP4 or HLS (`.m3u8`) link — **URL-encode spaces
  and parentheses** (`%20`, `%28`, `%29`). YouTube/Vimeo page links will not play.
- `poster` — any public image URL. The Archive's auto-thumbnail
  (`https://archive.org/services/img/<identifier>`) works for every item.
- `streamFormat` — `mp4` or `hls`. If omitted the channel auto-detects from the
  URL extension.

---

## 4. Moving to Cloudflare Stream later (optional upgrade)

You mentioned a Cloudflare **Stream** library. Archive.org is fine, but Stream
gives you adaptive HLS, no bot-blocking, and faster start times. To switch a
title, host it on Stream and change its feed entry to:

```json
"streamUrl": "https://customer-<code>.cloudflarestream.com/<video-id>/manifest/video.m3u8",
"streamFormat": "hls"
```

No channel change needed — it's all driven by the feed. Point me at your Stream
library any time and I'll migrate titles over.

---

## 5. Project layout

```
manifest                         Channel name, icons, splash
source/main.brs                  Entry point
components/
  MainScene.xml/.brs             Root scene + remote-feed bootstrap
  ContentLoader.xml/.brs         Task: fetch feed (remote → bundled fallback)
  SplashScreen.xml/.brs          Animated branded splash
  HomeScreen.xml/.brs            Netflix-style rows + spotlight hero
  PosterItem.xml/.brs            2:3 poster card w/ focus scale + glow
  DetailScreen.xml/.brs          Detail view + in-channel Video playback
images/                          Icons, splash, backdrops, fallback poster
feed/feed.json                   Bundled catalogue (fallback + starting point)
```

---

## 6. Publishing to the Roku Channel Store (when ready)

Sideload and test on hardware first. Then on the dev device:
**Installer → Package → Generate Package** (with your dev password) to produce a
signed `.pkg`, and submit it in the Roku developer dashboard with screenshots,
description, and a content rating appropriate for horror.
