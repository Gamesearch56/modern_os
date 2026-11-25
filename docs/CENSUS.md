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

Nothing is sent until **Settings → Privacy → Help developers track installed releases** is
on. That switch is off on a new install and on a settings file that
never had it. The address still comes from `census.url`, or from
`config.default.json` when the settings file has no address. An empty
address sends nothing even when the switch is on.

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
(`https://modern-census.<account>.workers.dev`). A new install copies
that file to `config.json` with the switch off. An update leaves an
existing `config.json` alone; when the switch is on and that file has
no address, the check uses the shipped one.

## Read the totals

```bash
scripts/census.sh counts
```

The command asks for the read secret and does not print it. The same secret can be passed as `CENSUS_READ_TOKEN` when nothing is there to type into.

```
Installs in the last 30 days

  v0.8.14  2
  v0.8.13  1
  total    3
```

That is machines whose update check reached the counter in the last 30
days, one per install id. A download of the ISO is not a machine, and a
machine that never comes online is not counted.

The read token stays on your side. The image does not contain it.
Anyone who can see the worker address can submit extra ids, so the
number is a count of notes, not a sealed audit. The address is not
listed anywhere except the config.
