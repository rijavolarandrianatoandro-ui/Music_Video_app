import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import worker from "../src/index.mjs";

const originalFetch = globalThis.fetch;
const originalCaches = globalThis.caches;

afterEach(() => {
  globalThis.fetch = originalFetch;
  globalThis.caches = originalCaches;
});

function request(path, method = "GET") {
  return new Request(`https://catalog.example.workers.dev${path}`, {
    method,
    headers: { "CF-Connecting-IP": "192.0.2.10" },
  });
}

function environment({ allowed = true } = {}) {
  return {
    YOUTUBE_API_KEY: "worker-secret",
    SEARCH_LIMITER: {
      async limit() {
        return { success: allowed };
      },
    },
  };
}

function context() {
  return { waitUntil(promise) { void promise; } };
}

function useEmptyCache() {
  globalThis.caches = {
    default: {
      async match() {
        return null;
      },
      async put() {},
    },
  };
}

test("search validates input and returns only YouTube API metadata", async () => {
  useEmptyCache();
  let upstreamUrl;
  globalThis.fetch = async (url) => {
    upstreamUrl = new URL(url);
    return Response.json({
      items: [
        {
          id: { videoId: "abcdefghijk" },
          snippet: { title: "Test", channelTitle: "Artist" },
        },
      ],
    });
  };

  const response = await worker.fetch(
    request("/api/search?q=ambient"),
    environment(),
    context(),
  );
  const payload = await response.json();

  assert.equal(response.status, 200);
  assert.equal(upstreamUrl.searchParams.get("key"), "worker-secret");
  assert.equal(upstreamUrl.searchParams.get("type"), "video");
  assert.equal(upstreamUrl.searchParams.get("videoCategoryId"), "10");
  assert.equal(payload.items[0].id.videoId, "abcdefghijk");
  assert.equal(JSON.stringify(payload).includes("worker-secret"), false);

  const invalid = await worker.fetch(
    request("/api/search?q=x"),
    environment(),
    context(),
  );
  assert.equal(invalid.status, 400);
});

test("invalid routes and rate-limited callers are rejected", async () => {
  useEmptyCache();
  const routeResponse = await worker.fetch(
    request("/api/anything"),
    environment(),
    context(),
  );
  assert.equal(routeResponse.status, 404);

  const limitedResponse = await worker.fetch(
    request("/api/search?q=ambient"),
    environment({ allowed: false }),
    context(),
  );
  assert.equal(limitedResponse.status, 429);
});

test("health endpoint checks Worker reachability without requiring an API key", async () => {
  const response = await worker.fetch(
    request("/api/health"),
    {},
    context(),
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
});

test("favorite metadata endpoint accepts only valid video IDs", async () => {
  useEmptyCache();
  let upstreamUrl;
  globalThis.fetch = async (url) => {
    upstreamUrl = new URL(url);
    return Response.json({
      items: [{ id: "abcdefghijk", snippet: { title: "Test" } }],
    });
  };

  const response = await worker.fetch(
    request("/api/videos?ids=abcdefghijk"),
    environment(),
    context(),
  );
  assert.equal(response.status, 200);
  assert.equal(upstreamUrl.pathname, "/youtube/v3/videos");
  assert.equal(upstreamUrl.searchParams.get("id"), "abcdefghijk");

  const invalid = await worker.fetch(
    request("/api/videos?ids=not-a-video-id"),
    environment(),
    context(),
  );
  assert.equal(invalid.status, 400);
});

test("regional trending requests use YouTube's music chart for selected country", async () => {
  useEmptyCache();
  let upstreamUrl;
  globalThis.fetch = async (url) => {
    upstreamUrl = new URL(url);
    return Response.json({ items: [] });
  };

  const response = await worker.fetch(
    request("/api/trending?region=mg"),
    environment(),
    context(),
  );
  assert.equal(response.status, 200);
  assert.equal(upstreamUrl.searchParams.get("chart"), "mostPopular");
  assert.equal(upstreamUrl.searchParams.get("regionCode"), "MG");
  assert.equal(upstreamUrl.searchParams.get("videoCategoryId"), "10");

  const invalid = await worker.fetch(
    request("/api/trending?region=XXX"),
    environment(),
    context(),
  );
  assert.equal(invalid.status, 400);
});
