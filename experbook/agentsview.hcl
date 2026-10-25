job "agentsview" {
  datacenters = ["dc1"]
  type        = "service"

  group "agentsview" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    network {
      port "http" {
        static = 8080
        to     = 8080
      }
    }

    service {
      name     = "agentsview"
      port     = "http"
      provider = "nomad"
      address  = "127.0.0.1"

      check {
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "agentsview" {
      driver = "podman"

      config {
        image        = "ghcr.io/kenn-io/agentsview:stable"
        force_pull = true
        network_mode = "host"

        # 覆盖镜像默认 CMD (--host 0.0.0.0)，host 网络下只听回环
        args = ["--host", "127.0.0.1", "--no-browser"]

        volumes = [
          # SQLite 归档 / 索引，容器内以 root 跑，放 /datapool 下
          "/datapool/agentsview/data:/data",
          # 会话源，只读
          "/home/jing2uo/.claude/projects:/agents/claude:ro",
          "/home/jing2uo/.pi/agent/sessions:/agents/pi:ro",
        ]
      }

      env {
        CLAUDE_PROJECTS_DIR = "/agents/claude"
        PI_DIR              = "/agents/pi"

        AGENTSVIEW_DATA_DIR             = "/data"
        AGENTSVIEW_DISABLE_UPDATE_CHECK = "1"
      }

      resources {
        cpu    = 1000
        memory = 1024
      }

      restart {
        attempts = 3
        interval = "5m"
        delay    = "15s"
        mode     = "delay"
      }
    }
  }
}
