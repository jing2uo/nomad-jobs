# CUPS 跑在容器里，宿主机不装 cups。
# 容器把 socket 放到宿主机 /run/cups/cups.sock，flatpak（--socket=cups）和 portal 打印对话框都直接用它。
#
# 首次部署前（一次性）：
#   sudo mkdir -p /datapool/cupsd
#   echo 'd /run/cups 0755 root root -' | sudo tee /etc/tmpfiles.d/cups-socket.conf
#   sudo systemd-tmpfiles --create /etc/tmpfiles.d/cups-socket.conf
#
# 部署：nomad job run experbook/cupsd.hcl
# 管理页面：http://127.0.0.1:631 （账号密码 print/print，只监听本机回环）
# 添加 driverless 网络打印机：
#   nomad alloc exec -job cupsd -task cupsd lpadmin -p home -E -v ipp://打印机IP/ipp/print -m everywhere

job "cupsd" {
  datacenters = ["dc1"]
  type        = "service"

  group "cupsd" {
    count = 1

    update {
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
    }

    network {
      port "ipp" {
        static = 631
      }
    }

    service {
      name     = "cupsd"
      port     = "ipp"
      provider = "nomad"
      address  = "127.0.0.1"

      check {
        type     = "tcp"
        port     = "ipp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    # /datapool/cupsd 为空时用镜像自带的 /etc/cups 初始化，并把监听地址收窄到 127.0.0.1
    task "seed" {
      driver = "podman"

      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      config {
        image   = "docker.io/olbat/cupsd:latest"
        command = "/bin/sh"
        args = [
          "-c",
          "[ -e /seed/cupsd.conf ] || cp -a /etc/cups/. /seed/; sed -i 's/^Listen \\*:631$/Listen 127.0.0.1:631/' /seed/cupsd.conf",
        ]

        volumes = [
          "/datapool/cupsd:/seed",
        ]
      }

      resources {
        cpu    = 100
        memory = 64
      }
    }

    task "cupsd" {
      driver = "podman"

      config {
        image        = "docker.io/olbat/cupsd:latest"
        network_mode = "host"

        # 本地 socket 认证（PeerCred）要求容器里有同名同 uid 的用户，否则 Send-Document 返回 401
        command = "/bin/sh"
        args = [
          "-c",
          "getent passwd jing2uo >/dev/null || useradd -o -u 1000 -M -N jing2uo; exec /usr/sbin/cupsd -f",
        ]

        volumes = [
          "/datapool/cupsd:/etc/cups",
          "/run/cups:/run/cups",
        ]

        # nofile 过大时 cupsd 会报 cupsdDoSelect() failed
        ulimit {
          nofile = "4096:8192"
        }
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
