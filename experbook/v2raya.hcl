job "v2raya" {
  datacenters = ["dc1"]
  type        = "service"

  group "v2raya" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    network {
      port "http" {
        static = 2017
        to     = 2017
      }
    }

    service {
      name     = "v2raya"
      port     = "http"
      provider = "nomad"
      address  = "${attr.unique.network.ip-address}"

      check {
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "v2raya" {
      driver = "podman"

      config {
        image = "docker.io/mzz2017/v2raya:latest"
        force_pull = true
        network_mode = "host"
        
        volumes = [
          "/datapool/v2raya:/etc/v2raya",
        ]
      }

      env {
        V2RAYA_LOG_FILE  = "/tmp/v2raya.log"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
