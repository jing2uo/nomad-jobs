job "traefik" {
  datacenters = ["dc1"]
  type        = "service"

  group "traefik" {
    network {
      mode = "host"
    }

    service {
      name     = "traefik"
      port     = 80
      provider = "nomad"
      tags     = ["traefik.enable=false"]
    }

    task "traefik" {
      driver = "podman"

      config {
        image        = "docker.io/library/traefik:latest"
        network_mode = "host"

        args = [
          "--api.insecure=true",
          "--api.disabledashboardad=true",
          "--entrypoints.web.address=:80",
          "--providers.nomad=true",
          "--providers.nomad.endpoint.address=http://127.0.0.1:4646",
          # 只暴露显式带 traefik.enable=true 的服务
          "--providers.nomad.exposedByDefault=false",
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}