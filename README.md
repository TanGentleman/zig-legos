# zig-legos

A kit for small Zig web apps on spider v0.12.0 and HTMX: a Claude Code skill
with an app template, a worked example and pinned tools. Linux x86_64 only.

```sh
git clone https://github.com/TanGentleman/zig-legos && cd zig-legos
skills/spider/prove.sh --no-demo /tmp/my-app   # scaffold, build, serve, curl /up
```

Needs bash, curl, git, python3, tar, unzip and, until the `ci-tools` release is
reseeded, [Zig 0.17.1](https://ziglang.org/download/) on PATH. Details:
[IMPLEMENTATION.md](IMPLEMENTATION.md), [ROADMAP.md](ROADMAP.md).
