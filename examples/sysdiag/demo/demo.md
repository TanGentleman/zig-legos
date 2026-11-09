# sysdiag — live system usage dashboard (spider + HTMX)

*2026-11-08T06:17:56Z by Showboat 0.6.1*
<!-- showboat-id: 4fdf09bf-5988-40f0-8b62-f712cbd687d7 -->

Single-binary Zig web server on spider v0.12.0, built with the pinned Zig 0.17.1. Metrics come from /proc and a statfs(2) syscall; the page polls a server-rendered HTMX fragment every 2s. The server is already running on :3000.

```bash
curl -s localhost:3000/up; echo
```

```output
OK
```

```bash
curl -s localhost:3000/api/metrics | python3 -m json.tool
```

```output
{
    "hostname": "devin-box",
    "kernel": "6.8.0-1060-aws",
    "uptime_secs": 970,
    "load1": 0.02,
    "load5": 0.37,
    "load15": 0.4,
    "procs_total": 243,
    "cpu_pct": 8.164116560349655,
    "cores": 8,
    "mem_total_kb": 32866572,
    "mem_avail_kb": 31302636,
    "swap_total_kb": 0,
    "swap_free_kb": 0,
    "disk_total_b": 133003395072,
    "disk_avail_b": 114886238208
}
```

```bash
curl -s localhost:3000/metrics | head -6; echo
```

```output
<div class="card">
  <div class="label">CPU</div>
  <div class="value">14.6<span class="unit">%</span></div>
  <div class="track"><div class="bar" style="width:14.6%"></div></div>
  <div class="detail">8 cores &middot; load 0.02 / 0.37 / 0.40</div>
</div>

```

```bash {image}
![sysdiag dashboard](/tmp/sysdiag.png)
```

![sysdiag dashboard](638d6a53-2026-11-08.png)
