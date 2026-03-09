job "syncthing" {
  datacenters = ["dc1"]
  type        = "service"

  group "syncthing" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    network {
      port "http" {
        static = 8384
        to     = 8384
      }
    }

    service {
      name     = "syncthing"
      port     = "http"
      provider = "nomad"
      address  = "${attr.unique.network.ip-address}"
      tags = [
  "traefik.enable=true",
  "traefik.http.routers.syncthing.rule=PathPrefix(`/syncthing`)",
  "traefik.http.middlewares.syncthing-strip.stripprefix.prefixes=/syncthing",
  "traefik.http.middlewares.syncthing-host.headers.customrequestheaders.Host=${attr.unique.network.ip-address}:8384",
  "traefik.http.middlewares.syncthing-slash.redirectregex.regex=^(.*)/syncthing$$",
  "traefik.http.middlewares.syncthing-slash.redirectregex.replacement=$${1}/syncthing/",
  "traefik.http.routers.syncthing.middlewares=syncthing-slash,syncthing-strip,syncthing-host",
  "traefik.http.services.syncthing.loadbalancer.server.port=8384",
]
      
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "syncthing" {
      driver = "podman"

      config {
        image        = "docker.io/syncthing/syncthing:latest"
        network_mode = "host"
        hostname     = "xeon"

        volumes = [
          "/datapool/syncthing:/var/syncthing",
        ]
      }

      env {
        PUID = "1000"
        PGID = "1000"
        TZ   = "Asia/Shanghai"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}