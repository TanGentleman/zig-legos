# spider-bundle — share the spider build-and-prove workflow

`pack.sh` assembles the `spider` skill into a **self-contained bundle** you can
hand to anyone — no tracers checkout required on their end.

```sh
plugins/spider-bundle/pack.sh [out-dir]      # default: ./spider-bundle
```

It produces a `spider-bundle/` dir (and a `.zip` if `zip` is installed)
containing the skill plus a vendored `tools.lock`, with the lock lookup repointed
at the vendored copy. The only thing the bundle reaches for at runtime is the
**public** `ci-tools` release (pinned binaries, checksum-verified) — that needs
network, not a checkout.

A recipient installs it with the instructions baked into the bundle's own
`README.md` (copy the skill dir into `~/.claude/skills/`).

## More info
[spider skill](/skills/spider/SKILL.md)
