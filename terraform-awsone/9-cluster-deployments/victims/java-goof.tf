# #############################################################################
# Deploy the vulnerable web application java-goof
# #############################################################################
resource "kubernetes_deployment_v1" "java_goof_deployment" {
  metadata {
    name = "java-goof"
    labels = {
      app = "java-goof"
    }
    namespace = var.namespace
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "java-goof"
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
          app = "java-goof"
        }
      }
      spec {
        container {
          image             = "mawinkler/java-goof"
          image_pull_policy = "Always"
          name              = "java-goof"
          port {
            container_port = 80
          }
        }
        restart_policy = "Always"
      }
    }
  }
}

resource "kubernetes_service_v1" "java_goof_service" {
  metadata {
    labels = {
      app = "java-goof"
    }
    name      = "java-goof-service"
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
      app = "java-goof"
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "java_goof_ingress" {
  wait_for_load_balancer = true

  metadata {
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
    }
    labels = {
      app = "java-goof"
    }
    name      = "java-goof-ingress"
    namespace = var.namespace
  }
  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          backend {
            service {
              name = "java-goof-service"
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

