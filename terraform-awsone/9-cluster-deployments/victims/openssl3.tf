# #############################################################################
# Deploy a vulnerable web application
# #############################################################################
resource "kubernetes_deployment_v1" "openssl3_deployment" {
  metadata {
    name = "web-app"
    labels = {
      app = "web-app"
    }
    namespace = var.namespace
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "web-app"
      }
    }
    strategy {
      rolling_update {
        max_surge       = "25%"
        max_unavailable = "25%"
      }
      type = "RollingUpdate"
    }
    template {
      metadata {
        labels = {
          app = "web-app"
        }
      }
      spec {
        container {
          image             = "raphabot/openssl3"
          image_pull_policy = "Always"
          name              = "web-app"
          port {
            container_port = 80
          }
        }
        restart_policy = "Always"
      }
    }
  }
}

resource "kubernetes_service_v1" "openssl3_service" {
  metadata {
    labels = {
      app = "web-app"
    }
    name      = "web-app-service"
    namespace = var.namespace
  }
  spec {
    external_traffic_policy = "Cluster"
    internal_traffic_policy = "Cluster"
    port {
      port        = 80
      target_port = 8080
    }
    selector = {
      app = "web-app"
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "openssl3_ingress" {
  wait_for_load_balancer = true

  metadata {
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
    labels = {
      app = "web-app"
    }
    name      = "web-app-ingress"
    namespace = var.namespace
  }
  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          backend {
            service {
              name = "web-app-service"
              port {
                number = 80
              }
            }
          }
          path = "/"
        }
      }
    }
  }
}

