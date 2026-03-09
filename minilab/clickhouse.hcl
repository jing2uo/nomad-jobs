job "clickhouse" {
  datacenters = ["dc1"]
  type        = "service"

  group "clickhouse" {
    count = 1

    network {
      port "http" {
        static = 8123
        to     = 8123
      }
      port "native" {
        static = 9000
        to     = 9000
      }
    }

    service {
      name     = "clickhouse"
      port     = "http"
      provider = "nomad"

      check {
        type     = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "clickhouse" {
      driver = "podman"

      config {
        image = "docker.io/clickhouse/clickhouse-server:latest"
        ports = ["http", "native"]

        volumes = [
          "/datapool/clickhouse/config.xml:/etc/clickhouse-server/config.xml",
          "/datapool/clickhouse/data:/var/lib/clickhouse",
          "/datapool/clickhouse/logs:/var/log/clickhouse-server",
        ]

        ulimit {
          nofile = "262144:262144"
        }
      }

      env {
        CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT = "1"
      }

      resources {
        cpu    = 4000
        memory = 4096
        memory_max = 8192 
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