// Free counter for ModernOS installs. One key per random install id,
// value is the release and the last day it checked for an update.
// Deploy on Cloudflare Workers with a KV binding named CENSUS and a
// secret READ_TOKEN. The machines never see the token.
const DAY = 24 * 60 * 60 * 1000;
const ID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const VER = /^v\d+\.\d+\.\d+$/;

export default {
    async fetch(req, env) {
        const path = new URL(req.url).pathname;
        if (req.method === "POST" && path === "/")
            return note(req, env);
        if (req.method === "GET" && path === "/")
            return totals(req, env);
        return new Response("no", { status: 404 });
    },
};

async function note(req, env) {
    let body;
    try {
        body = await req.json();
    } catch (e) {
        return new Response("bad", { status: 400 });
    }
    const id = String(body.id || "");
    const version = String(body.version || "");
    if (!ID.test(id) || !VER.test(version))
        return new Response("bad", { status: 400 });
    await env.CENSUS.put(id, JSON.stringify({ version, seen: Date.now() }));
    return new Response("ok");
}

async function totals(req, env) {
    if (req.headers.get("Authorization") !== "Bearer " + env.READ_TOKEN)
        return new Response("no", { status: 401 });
    const cutoff = Date.now() - 30 * DAY;
    const counts = {};
    let cursor;
    do {
        const page = await env.CENSUS.list({ cursor, limit: 1000 });
        for (const key of page.keys) {
            const raw = await env.CENSUS.get(key.name);
            if (!raw)
                continue;
            let rec;
            try {
                rec = JSON.parse(raw);
            } catch (e) {
                continue;
            }
            if (!rec || typeof rec.seen !== "number" || rec.seen < cutoff)
                continue;
            if (!VER.test(rec.version || ""))
                continue;
            counts[rec.version] = (counts[rec.version] || 0) + 1;
        }
        cursor = page.list_complete ? undefined : page.cursor;
    } while (cursor);
    return Response.json({ days: 30, versions: counts });
}
