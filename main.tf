locals {
        all_data = jsondecode(file("example.json"))
}


provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_deployment" "apple_app" {
  count = length(local.all_data.applications)
  metadata {
    name = local.all_data.applications[count.index].name
  }

  spec {
    replicas = local.all_data.applications[count.index].replicas

    selector {
      match_labels = {
        app = local.all_data.applications[count.index].name
      }
    }

    template {
      metadata {
        labels = {
          app = local.all_data.applications[count.index].name
        }
      }

      spec {
        container {
          name  = "${local.all_data.applications[count.index].name}-app"
          image = local.all_data.applications[count.index].image
          args  = "${split(", ", local.all_data.applications[count.index].args)}"
        }
      }
    }
  }
}


resource "kubernetes_service" "apple_service" {
  count = length(local.all_data.applications)
  metadata {
    name = "${local.all_data.applications[count.index].name}-service"
  }

  spec {
    port {
      name        = "${local.all_data.applications[count.index].name}-service0"
      protocol    = "TCP"
      port        = local.all_data.applications[count.index].port
      target_port = local.all_data.applications[count.index].port
    }

    selector = {
      app = "${local.all_data.applications[count.index].name}"
    }

    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "example_ingress" {
  count = length(local.all_data.applications)
  metadata {
    name = "${local.all_data.applications[count.index].name}-ingress"

    annotations = {
      "ingress.kubernetes.io/rewrite-target" = "/"

      "kubernetes.io/elb.port" = "80"
      "nginx.ingress.kubernetes.io/canary" = "true"

      "nginx.ingress.kubernetes.io/canary-weight" = local.all_data.applications[count.index].traffic_weight

      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "${local.all_data.applications[count.index].name}-service"

              port {
                number = local.all_data.applications[count.index].port
              }
            }
          }
        }
      }
    }
  }
}

