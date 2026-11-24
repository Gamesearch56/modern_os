# Install counts

How many machines run each release. A release clone already asks GitHub
which tag is newest. After that check it also tells a counter its
random id and its version, once a day. A development checkout, including
this PC, never does.

What is sent: `{ "id", "version" }`. The id is a random UUID created on
that machine (`~/.local/state/modern/install-id`, mode 0600). It is not
the hostname, the user, a serial, or an address. The counter keeps the
id, the version, and the time of the last note, and forgets a machine
that has not checked in for 30 days.

Nothing is sent while `census.url` is empty. That is the default.

## Turn it on

The counter is a Cloudflare Worker, on the free plan. From
`scripts/census/`:

```bash
npx wrangler kv namespace create CENSUS
```

Put the printed id into `scripts/census/wrangler.toml`, then:

```bash
npx wrangler secret put READ_TOKEN
npx wrangler deploy
```

Set `census.url` in `config.default.json` to the worker address
(`https://modern-census.<account>.workers.dev`). The next install and
the next update pick it up. A machine already installed keeps its own
`config.json`; add the same `census.url` there, or leave it empty to
stay out.

## Read the totals

```bash
CENSUS_READ_TOKEN='…' scripts/census.sh counts
```

```json
{ "days": 30, "versions": { "v0.8.14": 2 } }
```

That is machines whose update check reached the counter in the last 30
days, one per install id. A download of the ISO is not a machine, and a
machine that never comes online is not counted.

The read token stays on your side. The image does not contain it.
Anyone who can see the worker address can submit extra ids, so the
number is a count of notes, not a sealed audit. The address is not
listed anywhere except the config.
