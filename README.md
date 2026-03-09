# nomad_jobs

使用 [Nomad](https://www.nomadproject.io/) + [Podman](https://podman.io/) 管理容器服务的配置文件备份。

## 环境说明

- **调度器**：HashiCorp Nomad（任务类型均为 `service`，datacenter `dc1`）
- **容器运行时**：Podman（Nomad task driver 使用 `podman`）

## 目录结构

```
nomad_jobs/
├── experbook/
│   ├── clickhouse.hcl  # ClickHouse 数据库（HTTP 8123）
│   └── v2raya.hcl      # v2rayA 代理面板（HTTP 2017）
│
└── minilab/
    ├── clickhouse.hcl       # ClickHouse 数据库（HTTP 8123 / Native 9000）
    ├── clickhouse.config.xml # ClickHouse 自定义配置文件
    ├── gitea.hcl            # Gitea 代码托管（HTTP 3000 / SSH 2222）
    ├── oplist.hcl           # OpenList 文件列表服务（HTTP 5244）
    ├── syncthing.hcl        # Syncthing 文件同步（HTTP 8384）
    └── traefik.hcl          # Traefik 反向代理（host 网络模式）
```

## 使用方法

提交/更新某个 Job：

```bash
nomad job run minilab/gitea.hcl
```

查看 Job 状态：

```bash
nomad job status gitea
```

停止 Job：

```bash
nomad job stop gitea
```
