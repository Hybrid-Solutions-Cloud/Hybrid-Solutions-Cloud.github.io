const UPSTREAM_ORIGIN = "https://hybrid-solutions-cloud.github.io";
const PUBLIC_ORIGIN = "https://labs.hybridsolutions.cloud";

export default {
  async fetch(request) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      return new Response("Method not allowed", {
        status: 405,
        headers: { Allow: "GET, HEAD" },
      });
    }

    const incomingUrl = new URL(request.url);
    const upstreamUrl = new URL(
      `${incomingUrl.pathname}${incomingUrl.search}`,
      UPSTREAM_ORIGIN,
    );

    const upstreamHeaders = new Headers(request.headers);
    for (const name of [
      "authorization",
      "cookie",
      "cf-access-jwt-assertion",
      "cf-connecting-ip",
      "cf-ipcountry",
      "cf-ray",
      "x-forwarded-for",
      "x-forwarded-proto",
    ]) {
      upstreamHeaders.delete(name);
    }

    const upstreamResponse = await fetch(
      new Request(upstreamUrl, {
        method: request.method,
        headers: upstreamHeaders,
        redirect: "manual",
      }),
    );

    const responseHeaders = new Headers(upstreamResponse.headers);
    const location = responseHeaders.get("location");
    if (location?.startsWith(UPSTREAM_ORIGIN)) {
      responseHeaders.set("location", location.replace(UPSTREAM_ORIGIN, PUBLIC_ORIGIN));
    }

    responseHeaders.set("referrer-policy", "strict-origin-when-cross-origin");
    responseHeaders.set("x-content-type-options", "nosniff");
    responseHeaders.set("x-frame-options", "SAMEORIGIN");
    responseHeaders.set("x-hsc-origin", "github-pages");

    return new Response(request.method === "HEAD" ? null : upstreamResponse.body, {
      status: upstreamResponse.status,
      statusText: upstreamResponse.statusText,
      headers: responseHeaders,
    });
  },
};
