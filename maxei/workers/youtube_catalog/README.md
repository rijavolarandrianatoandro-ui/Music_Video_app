# Maxei YouTube catalog Worker

This Worker proxies only YouTube Data API metadata. It does not expose media
streams or download endpoints. The API key remains a Cloudflare Worker secret.

## Deploy

1. Enable YouTube Data API v3 in a Google Cloud project and create an API key
   restricted to that API. Set an appropriate API quota in Google Cloud.
2. Install Wrangler and authenticate with Cloudflare.
3. Change `ratelimits.namespace_id` in `wrangler.toml` to a positive integer
   unique within your Cloudflare account.
4. From this directory, set the secret and deploy:

   ```sh
   npx wrangler secret put YOUTUBE_API_KEY
   npx wrangler deploy
   ```

5. Configure the mobile app with the deployed Worker origin:

   ```sh
   flutter run --dart-define=YOUTUBE_CATALOG_WORKER_URL=https://YOUR-WORKER.workers.dev
   ```

   Use the same `--dart-define` when producing release builds. Do not put the
   YouTube API key in the Flutter app.

## Abuse and quota controls

The Worker exposes fixed, read-only YouTube endpoints, validates search text,
video IDs, and supported region codes, limits requests per client IP, and
caches metadata briefly.
Cloudflare's rate limiter is approximate and scoped by Cloudflare location; it
is not user authentication. A shared `x-app-token` embedded in a mobile app
would be extractable and is intentionally not used as a security boundary.
Monitor the Google API quota and tighten the Worker limits if needed.

Search results and saved favorites are metadata/references only. Playback must
open the video on YouTube. The Worker does not cache, proxy, or download audio
or video content.

`GET /api/trending?region=MG` returns YouTube's popular videos for the
selected ISO country code and the Music category. Maxei ranks this chart on
the device using the user's chosen artists and local listening library.
The UI must clearly identify YouTube as the source; do not relabel or conceal
that attribution. Trending results are videos and should not be described as
an exhaustive music release or song chart.

`GET /api/health` is a no-quota reachability check used to defer the first-run
artist picker until the Worker can be reached. The picker itself uses bundled
artist names and locally generated pixel illustrations; it fetches no artist
photos and can also be opened from Settings while offline.

Run the Worker unit tests from this directory with:

```sh
node --test test/index.test.mjs
```
