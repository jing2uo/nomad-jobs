job "openlist" {
  datacenters = ["dc1"]
  type        = "service"

  group "openlist" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    network {
      port "http" {
        static = 5244
        to     = 5244
      }
    }

    service {
      name     = "openlist"
      port     = "http"
      provider = "nomad"
      address  = "${attr.unique.network.ip-address}"
      
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.openlist.rule=PathPrefix(`/oplist`)",
      ]
      
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "openlist" {
      driver = "podman"

      config {
        image = "docker.io/openlistteam/openlist:latest"
        ports = ["http"]

        volumes = [
          "/datapool/openlist:/opt/openlist/data",
        ]
      }

      env {
        UMASK = "022"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}