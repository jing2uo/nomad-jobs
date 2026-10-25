# 导航页：自动列出 Nomad 里注册的所有 service，增删服务后页面自动更新。
# 部署：nomad job run experbook/nav.hcl
# 访问：http://localhost/
# 想在导航页隐藏某个服务：在它的 service 块里加 tags = ["nav-hide"]
# 图标/标题：改下面 template 里的 $cfg（按 service 名索引，字段都可省略；
# icon 是服务自己站点上的路径，取不到时显示首字母）
# 账号密码：存在 Nomad Variable nomad/jobs/nav 里，值格式 账号:密码，$cfg 里用 cred 指定键名。
# 部署前必须先写入该变量，否则 template 会一直等待：
#   nomad var put -force nomad/jobs/nav v2raya_admin=admin:密码 cupsd_admin=print:print
#   （-force 是整体替换，已有的键要一起写上；详见 AGENTS.md）
#   nomad var get nomad/jobs/nav

job "nav" {
  datacenters = ["dc1"]
  type        = "service"

  group "nav" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    network {
      port "http" {
        static = 80
      }
    }

    service {
      name     = "nav"
      port     = "http"
      provider = "nomad"
      address  = "127.0.0.1"
      tags     = ["nav-hide"]

      check {
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nav" {
      driver = "podman"

      config {
        image        = "docker.io/library/busybox:stable"
        network_mode = "host"
        command      = "httpd"
        args         = ["-f", "-p", "127.0.0.1:80", "-h", "/local/www"]
      }

      # httpd 每次请求都读文件，重新渲染后无需重启
      template {
        destination = "local/www/index.html"
        change_mode = "noop"
        data        = <<EOF
{{- $cfg := parseJSON `{
  "agentsview": { "title": "AgentsView", "icon": "/favicon.svg" },
  "cupsd":      { "title": "CUPS 打印", "icon": "/apple-touch-icon.png", "cred": "cupsd_admin" },
  "v2raya":     { "title": "v2rayA", "icon": "/static/v2raya-icon.svg", "cred": "v2raya_admin" }
}` -}}
{{- $vars := nomadVar "nomad/jobs/nav" -}}
<!doctype html>
<html lang="zh">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>导航</title>
<style>
  :root { --bg: #f3f4f8; --card: #fff; --fg: #1f2330; --muted: #8a90a2; --line: #e6e8ef; --accent: #4f6bed; }
  @media (prefers-color-scheme: dark) {
    :root { --bg: #15171e; --card: #1f222b; --fg: #e8eaf0; --muted: #8b90a0; --line: #2c303b; --accent: #7b93ff; }
  }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; background: var(--bg); color: var(--fg);
         font-family: system-ui, -apple-system, "Noto Sans CJK SC", sans-serif; }
  header { text-align: center; padding: 3.5rem 1rem 2rem; }
  header h1 { margin: 0; font-size: 1.8rem; font-weight: 600; letter-spacing: .02em; }
  header p { margin: .5rem 0 0; color: var(--muted); font-size: .9rem; }
  main { max-width: 960px; margin: 0 auto; padding: 0 1.5rem 3rem;
         display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); grid-auto-rows: 1fr; gap: 1rem; }
  .card { background: var(--card); border: 1px solid var(--line); border-radius: 14px; padding: 1.1rem 1.2rem;
          display: flex; flex-direction: column; justify-content: center;
          transition: transform .15s, box-shadow .15s, border-color .15s; }
  .card:hover { transform: translateY(-2px); box-shadow: 0 8px 24px rgba(0,0,0,.08); border-color: var(--accent); }
  .head { display: flex; align-items: center; justify-content: center; gap: .9rem; text-decoration: none; color: inherit; }
  .icon { position: relative; flex: none; width: 44px; height: 44px; border-radius: 10px; overflow: hidden;
          background: var(--accent); color: #fff; display: grid; place-items: center;
          font-weight: 700; font-size: 1.2rem; text-transform: uppercase; }
  .icon img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: contain;
              background: var(--card); padding: 4px; }
  .name { font-size: 1.05rem; font-weight: 600; }
  .addr { color: var(--muted); font-size: .8rem; margin-top: .15rem; font-family: ui-monospace, monospace; }
  .cred { margin-top: .9rem; padding-top: .8rem; border-top: 1px dashed var(--line);
          display: flex; justify-content: center; gap: .5rem; flex-wrap: wrap; }
  .cred button { border: 1px solid var(--line); background: transparent; color: var(--fg); cursor: pointer;
                 border-radius: 6px; padding: .25rem .6rem; font: .8rem ui-monospace, monospace; }
  .cred button:hover { border-color: var(--accent); color: var(--accent); }
  .cred button span { color: var(--muted); margin-right: .3rem; }
  .cred button.ok { border-color: #3fb950; color: #3fb950; }
</style>
</head>
<body>
<header>
  <h1>导航</h1>
  <p>Nomad 服务自动发现 · 点击账号密码可复制</p>
</header>
<main>
{{- range nomadServices }}{{ if not (.Tags | contains "nav-hide") }}{{ $name := .Name }}{{ $c := index $cfg $name }}
{{- range nomadService .Name }}
{{- $host := .Address }}{{ if eq $host "127.0.0.1" }}{{ $host = "localhost" }}{{ end }}
{{- $url := printf "http://%s:%d" $host .Port }}
  <div class="card">
    <a class="head" href="{{ $url }}/">
      <div class="icon">{{ printf "%.1s" $name }}{{ with $c }}{{ with .icon }}<img src="{{ $url }}{{ . }}" alt="" onerror="this.remove()">{{ end }}{{ end }}</div>
      <div>
        <div class="name">{{ with $c }}{{ with .title }}{{ . }}{{ else }}{{ $name }}{{ end }}{{ else }}{{ $name }}{{ end }}</div>
        <div class="addr">{{ $host }}:{{ .Port }}</div>
      </div>
    </a>
    {{- with $c }}{{ with .cred }}{{ with printf "%s" (index $vars .) }}{{ $kv := split ":" . }}
    {{- $user := index $kv 0 }}{{ $pass := join ":" (slice $kv 1) }}
    <div class="cred">
      <button data-copy="{{ $user }}"><span>账号</span>{{ $user }}</button>
      <button data-copy="{{ $pass }}"><span>密码</span>{{ $pass }}</button>
    </div>
    {{- end }}{{ end }}{{ end }}
  </div>
{{- end }}{{ end }}
{{- end }}
  <div class="card">
    <a class="head" href="http://localhost:4646/ui/">
      <div class="icon">N<img src="http://localhost:4646/ui/favicon.ico" alt="" onerror="this.remove()"></div>
      <div>
        <div class="name">Nomad</div>
        <div class="addr">localhost:4646</div>
      </div>
    </a>
  </div>
</main>
<script>
  // 非 https/localhost 页面没有 navigator.clipboard，回退到 execCommand
  function copyText(t) {
    if (navigator.clipboard) return navigator.clipboard.writeText(t);
    const a = document.createElement("textarea");
    a.value = t;
    a.style.position = "fixed";
    a.style.opacity = "0";
    document.body.appendChild(a);
    a.select();
    document.execCommand("copy");
    a.remove();
    return Promise.resolve();
  }
  document.addEventListener("click", async (e) => {
    const b = e.target.closest("button[data-copy]");
    if (!b) return;
    await copyText(b.dataset.copy);
    b.classList.add("ok");
    setTimeout(() => b.classList.remove("ok"), 1000);
  });
</script>
</body>
</html>
EOF
      }

      resources {
        cpu    = 50
        memory = 32
      }
    }
  }
}
