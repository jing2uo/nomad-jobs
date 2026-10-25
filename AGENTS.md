# AGENTS.md — 给 agent 的操作指南

本仓库是两台机器上 Nomad job 的配置备份，也是唯一的事实来源：**仓库里的 hcl 必须和 Nomad 上实际运行的一致**。
新增、修改、删除应用时按本文操作。仓库是 **GitHub 公开仓库**，任何密码都不能进 git。

## 环境

| 目录 | 机器 | Nomad 地址 | 说明 |
|---|---|---|---|
| `experbook/` | 本机笔记本（10.102.1.166） | `http://127.0.0.1:4646`（默认） | 桌面机，大部分服务只给自己用 |
| `minilab/` | 家里服务器（10.102.1.188） | `NOMAD_ADDR=http://10.102.1.188:4646` | 局域网服务，前面有 Traefik（:80） |

- 两台各自是**独立的单节点集群**（server + client 一体），job、variable 互不相通。
- 操作 minilab 时每条命令都要带 `NOMAD_ADDR=http://10.102.1.188:4646`，别把 job 提交错集群。
- task driver 一律 `podman`（rootful）；experbook 上 docker driver 被禁用。
- 两边都没开 ACL，4646 对局域网开放。

## 编写新 hcl 的约定

参照同目录已有文件的写法（`experbook/v2raya.hcl`、`minilab/gitea.hcl` 是典型）：

```hcl
job "<name>" {
  datacenters = ["dc1"]
  type        = "service"

  group "<name>" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    network {
      port "http" {
        static = <端口>
      }
    }

    service {
      name     = "<name>"
      port     = "http"
      provider = "nomad"
      address  = "${attr.unique.network.ip-address}"   # 只给本机用的服务写 "127.0.0.1"

      check {
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "<name>" {
      driver = "podman"

      config {
        image        = "docker.io/<org>/<image>:<tag>"   # 写全 registry 前缀
        network_mode = "host"

        volumes = [
          "/datapool/<name>:/data",
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
```

- 文件名：`<机器目录>/<job 名>.hcl`，job 名、group 名、task 名、service 名保持一致。
- 持久化数据统一放宿主机 `/datapool/<name>/`，用 bind mount（podman driver 不支持 named volume）。
- **必须有 `service` 块**（`provider = "nomad"`），否则导航页看不到它。
- 端口先查空闲：experbook 用 `ss -ltn`；minilab 上看已有 job 的 static 端口，再 `curl` 一下确认没人占。
- 管理界面没有认证、或默认密码是公开的服务（例如 cupsd），只监听 `127.0.0.1`，service 的 `address` 也写 `127.0.0.1`。
- 一次性的部署前准备（`mkdir`、tmpfiles 规则等需要 sudo 的步骤）写在文件头注释里，参考 `experbook/cupsd.hcl`。

## 接入导航页（nav）

每台机器都跑了一个 `nav` job（`experbook/nav.hcl` → http://localhost/，`minilab/nav.hcl` → http://10.102.1.188/），
它用 Nomad template 的 `nomadServices` 自动列出所有 service，增删服务后页面自动更新，**一般什么都不用做**。

需要定制时改对应 `nav.hcl` 顶部 template 里的 `$cfg` JSON（按 service 名索引，字段都可省略）：

| 字段 | 作用 |
|---|---|
| `title` | 显示名称，默认用 service 名 |
| `icon` | 图标：服务站点上的路径（如 `/favicon.svg`），或完整的 `http(s)://`、`data:` 地址；取不到显示首字母 |
| `cred` | 账号密码在 Nomad Variable 里的键名（见下节） |
| `port`、`path` | 仅 minilab：覆盖链接端口 / 追加路径（如 Traefik 指到 `:8080/dashboard/`） |

- 找图标：`curl -s http://<地址>/ | grep -oiE '<link[^>]*icon[^>]*>'`，再 `curl -o /dev/null -w '%{http_code} %{content_type}'` 确认能取到且是图片。
- 不想在导航页出现：service 加 `tags = ["nav-hide"]`。
- experbook 的 nav 会把 `127.0.0.1` 显示成 `localhost`（有的服务只认 localhost）。
- minilab 的 nav 会识别 service tags 里的 Traefik `PathPrefix` 规则，链接自动走 Traefik 路径（如 gitea → `/git/`）。

## Traefik（仅 minilab）

- `exposedByDefault=false`：只有 service tags 带 `traefik.enable=true` 的才会被路由。不走 Traefik 的服务直接用 `IP:端口` 访问，不受影响。
- 路由按路径前缀，参考 `minilab/gitea.hcl` 的 tags（`PathPrefix` + `stripprefix` 中间件）。没有域名，别用 `Host()` 规则。
- `nav` 占了优先级最低的 `PathPrefix(/)` 兜底路由，新路由不用管它。
- 核对路由：`curl -s http://10.102.1.188:8080/api/http/routers`。

## 账号密码：只放 Nomad Variables

导航页显示的账号密码存在各自集群的 Nomad Variable `nomad/jobs/nav` 里，值的格式是 `账号:密码`，键名约定 `<服务>_admin`。
job 只能隐式读取 `nomad/jobs/<job>` 这几个精确路径，**不要放到子路径**。

`nomad var put` 的行为（已实测）：变量已存在时，不加 `-force` 会报错；加 `-force` 是**整体替换**，没写的键会被删掉。
所以新增或修改一个键时，要把已有的键一起写进去：

```bash
# 1. 先看现有的键和值
nomad var get -out=go-template -template='{{range $k,$v := .Items}}{{$k}}={{$v}}{{"\n"}}{{end}}' nomad/jobs/nav
# 2. 带上全部键整体写回；通过 stdin 传 JSON，避免密码出现在命令行参数里
printf '{"Items":{"old_admin":"u:p","new_admin":"u2:p2"}}' | nomad var put -force -in=json nomad/jobs/nav -
```

再在 nav 的 `$cfg` 里给服务加 `"cred": "<服务>_admin"`。

- experbook 的 nav **强依赖**这个变量：变量不存在时 template 会一直阻塞，task 起不来。minilab 的 nav 变量可有可无。
- 推送前扫描：`git diff --cached | grep -nEi 'pass|token|secret|key'`，确认没有明文密码。

## 新增应用流程

1. 在对应目录写 `<name>.hcl`，遵守上面的约定。
2. `nomad job validate <file>`，再用 `nomad job plan <file>` 看一下改动。
3. 文件头注释里的准备步骤需要 sudo 的，交给用户执行，不要自己 sudo。
4. `nomad job run <file>`，等 deployment successful。
5. 验证：`nomad job status <name>`；用 `curl` 访问服务确认 200；确认 nav 页面出现了它，图标能加载。
6. 需要的话，按上面两节补上 nav 的 `$cfg` 和账号密码变量，然后重新部署 nav。
7. 在 README 的目录树里加一行。
8. 提交、推送（见下文）。

## 修改应用

- 改仓库里的文件，然后 `plan` → `run`。**不要**只在 Nomad UI 或命令行里改而不同步仓库。
- 用户直接在 Nomad 上改过的话，用运行中的版本更新仓库：
  `nomad job inspect -hcl <name> | diff <file> -`，确认差异后用 `nomad job inspect -hcl <name>` 覆盖文件（去掉末尾多出的空行）。
- `inspect -hcl` 返回的是**最后一次产生新版本时**提交的源文件。只改注释的提交不会产生新版本，所以 diff 里只差注释时可以忽略，不要拿运行版本把仓库里的新注释盖掉。

## 删除应用

1. 和用户确认，尤其是数据目录要不要留。
2. `nomad job stop -purge <name>`。
3. `git rm` 对应的 hcl，同时删掉 README 里那一行。
4. 清掉 nav `$cfg` 里对应的条目；有账号密码的话，从变量里去掉这个键（按上面的方法整体写回）。
5. `/datapool/<name>` 里的数据**只有用户明确同意才删**。

## 提交和推送

- 每个逻辑改动一个 commit，message 风格：`<机器目录>: <做了什么>`，例如 `minilab: 添加 nav 导航页`。
- 只 `git add` 自己改的文件。工作区里如果有用户自己的改动，先问再决定要不要带上。
- `git add` 要等所有文件编辑完成后再执行，不要和编辑操作并行，否则可能漏掉文件。
- 推送前做密码扫描（见上文）。远程是 `git@github.com:jing2uo/nomad-jobs.git`。

## 踩过的坑

- **空目录 bind mount 会盖掉镜像里的默认配置**：用 prestart task 先把镜像自带的文件复制出来再挂载，参考 `experbook/cupsd.hcl` 的 `seed` task。
- **podman 不会自动创建不存在的宿主机挂载目录**，会直接报错。`/run` 下的目录每次开机都会清空，要用 `/etc/tmpfiles.d/` 规则在开机时创建。
- **在多 task 的 alloc 里执行命令**：`nomad alloc exec -job` 选不中 task，要写成 `nomad alloc exec -task <task> <alloc-id> <cmd>`。alloc ID 用 `nomad job allocs <job>` 查，每次重新部署都会变。
- **容器里的 nofile 上限太大**会让一些老程序出问题（例如 cupsd 的 `cupsdDoSelect() failed`），在 podman config 里用 `ulimit { nofile = "4096:8192" }` 限小。
- **unix socket 的 PeerCred 认证**要求容器里有和宿主机同名、同 uid 的用户（cupsd 的 `Send-Document` 返回 401 就是这个原因）。
- **Flatpak 应用只在启动时绑定 socket**：提供 socket 的容器重启后，相关应用也要重启。
- **busybox httpd** 足够用来托管 template 渲染出来的静态页（`change_mode = "noop"`），不用上 nginx。
- **从 `http://IP` 打开的页面没有 `navigator.clipboard`**（不是安全上下文），复制功能要有 `execCommand` 兜底。
