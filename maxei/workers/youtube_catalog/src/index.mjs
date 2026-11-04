const jsonHeaders = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "public, max-age=300",
  "X-Content-Type-Options": "nosniff",
};

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

function validVideoId(id) {
  return /^[A-Za-z0-9_-]{11}$/.test(id);
}

const supportedRegions = new Set([
  "US", "GB", "FR", "MG", "AT", "CA", "AU", "BR", "MX", "AR", "CO", "BO",
  "CR", "DO", "EC", "GT", "PA", "PY", "UY", "VE", "ES", "PT", "DE", "IT",
  "BE", "CH", "CZ", "DK", "FI", "GR", "HU", "IE", "NO", "PL", "RO", "SE",
  "UA", "NL", "RU", "TR", "IL", "AE", "SA", "EG", "MA", "DZ", "TN", "NG",
  "ZA", "KE", "GH", "CI", "SN", "UG", "TZ", "ET", "CM", "MU", "MZ", "ZM",
  "ZW", "JP", "KR", "IN", "ID", "PH", "TH", "BD", "HK", "KZ", "MY", "NP",
  "PK", "SG", "LK", "TW", "VN", "NZ", "CL", "PE", "JM", "PR",
]);

async function fetchYoutube(url, apiKey) {
  url.searchParams.set("key", apiKey);
  const response = await fetch(url);
  if (!response.ok) {
    return jsonResponse({ error: "youtube_unavailable" }, 502);
  }
  const payload = await response.json();
  return jsonResponse(payload);
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (request.method !== "GET") {
      return jsonResponse({ error: "method_not_allowed" }, 405);
    }

    if (url.pathname === "/api/health") {
      return jsonResponse({ ok: true }, 200);
    }

    if (
      url.pathname !== "/api/search" &&
      url.pathname !== "/api/videos" &&
      url.pathname !== "/api/trending"
    ) {
      return jsonResponse({ error: "not_found" }, 404);
    }

    if (!env.YOUTUBE_API_KEY || !env.SEARCH_LIMITER) {
      return jsonResponse({ error: "service_unavailable" }, 503);
    }

    const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
    const { success } = await env.SEARCH_LIMITER.limit({ key: clientIp });
    if (!success) {
      return jsonResponse({ error: "rate_limited" }, 429);
    }

    const cache = caches.default;
    const cacheKey = new Request(url.toString(), { method: "GET" });
    const cached = await cache.match(cacheKey);
    if (cached) return cached;

    let youtubeUrl;
    if (url.pathname === "/api/search") {
      const query = (url.searchParams.get("q") || "").trim();
      if (query.length < 2 || query.length > 100) {
        return jsonResponse({ error: "invalid_query" }, 400);
      }

      youtubeUrl = new URL("https://www.googleapis.com/youtube/v3/search");
      youtubeUrl.searchParams.set("part", "snippet");
      youtubeUrl.searchParams.set("type", "video");
      youtubeUrl.searchParams.set("videoCategoryId", "10");
      youtubeUrl.searchParams.set("maxResults", "10");
      youtubeUrl.searchParams.set(
        "fields",
        "items(id(videoId),snippet(title,channelTitle,publishedAt,thumbnails(medium(url))))",
      );
      youtubeUrl.searchParams.set("q", query);
    } else if (url.pathname === "/api/videos") {
      const ids = [...new Set((url.searchParams.get("ids") || "").split(","))];
      if (
        ids.length === 0 ||
        ids.length > 50 ||
        ids.some((id) => !validVideoId(id))
      ) {
        return jsonResponse({ error: "invalid_video_ids" }, 400);
      }

      youtubeUrl = new URL("https://www.googleapis.com/youtube/v3/videos");
      youtubeUrl.searchParams.set("part", "snippet");
      youtubeUrl.searchParams.set("id", ids.join(","));
      youtubeUrl.searchParams.set(
        "fields",
        "items(id,snippet(title,channelTitle,publishedAt,thumbnails(medium(url))))",
      );
    } else {
      const regionCode = (url.searchParams.get("region") || "").toUpperCase();
      if (!supportedRegions.has(regionCode)) {
        return jsonResponse({ error: "invalid_region" }, 400);
      }

      youtubeUrl = new URL("https://www.googleapis.com/youtube/v3/videos");
      youtubeUrl.searchParams.set("part", "snippet");
      youtubeUrl.searchParams.set("chart", "mostPopular");
      youtubeUrl.searchParams.set("regionCode", regionCode);
      youtubeUrl.searchParams.set("videoCategoryId", "10");
      youtubeUrl.searchParams.set("maxResults", "50");
      youtubeUrl.searchParams.set(
        "fields",
        "items(id,snippet(title,channelTitle,publishedAt,thumbnails(medium(url))))",
      );
    }

    try {
      const response = await fetchYoutube(youtubeUrl, env.YOUTUBE_API_KEY);
      if (response.status === 200) {
        ctx.waitUntil(cache.put(cacheKey, response.clone()));
      }
      return response;
    } catch {
      return jsonResponse({ error: "youtube_unavailable" }, 502);
    }
  },
};
