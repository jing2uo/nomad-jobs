job "gitea" {
  datacenters = ["dc1"]
  type        = "service"

  group "gitea" {
    count = 1

    network {
      port "http" {
        static = 3000
        to     = 3000
      }
      port "ssh" {
        static = 2222
        to     = 2222
      }
    }

    service {
      name     = "gitea"
      port     = "http"
      provider = "nomad"

      address  = "${attr.unique.network.ip-address}"
      tags = [
        "traefik.enable=true",
        "traefik.http.routers.gitea.rule=PathPrefix(`/git`)",
        "traefik.http.middlewares.gitea-strip.stripprefix.prefixes=/git",
        "traefik.http.routers.gitea.middlewares=gitea-strip",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "gitea" {
      driver = "podman"

      config {
        image = "docker.io/gitea/gitea:latest"
        ports = ["http", "ssh"]

        volumes = [
          "/datapool/gitea:/data",
          "/etc/localtime:/etc/localtime:ro",
        ]
      }

      env {
        USER_UID = "1001"
        USER_GID = "1001"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
