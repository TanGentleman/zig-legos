# sysdiag — live system usage dashboard (spider + HTMX)

*2026-11-08T04:56:17Z by Showboat 0.6.1*
<!-- showboat-id: bab75198-125c-4f6f-89ed-8f0859093775 -->

Single-binary Zig web server on spider v0.11.0, built with the pinned Zig 0.17.1. Metrics come from /proc and a statfs(2) syscall; the page polls a server-rendered HTMX fragment every 2s. The server is already running on :3000.

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
    "uptime_secs": 907,
    "load1": 0.57,
    "load5": 0.43,
    "load15": 0.29,
    "procs_total": 231,
    "cpu_pct": 6.606207135833723,
    "cores": 8,
    "mem_total_kb": 32866612,
    "mem_avail_kb": 31357324,
    "swap_total_kb": 0,
    "swap_free_kb": 0,
    "disk_total_b": 133003395072,
    "disk_avail_b": 115679686656
}
```

```bash
curl -s localhost:3000/metrics | head -6; echo
```

```output
<div class="card">
  <div class="label">CPU</div>
  <div class="value">21.0<span class="unit">%</span></div>
  <div class="track"><div class="bar" style="width:21.0%"></div></div>
  <div class="detail">8 cores &middot; load 0.57 / 0.43 / 0.29</div>
</div>

```

The page itself, captured with rodney (headless Chrome) after one poll:

```bash {image}
![sysdiag dashboard](/tmp/sysdiag.png)
```

![sysdiag dashboard](09552cf2-2026-11-08.png)
