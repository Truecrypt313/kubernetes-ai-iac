terraform {
  required_version = "= 1.17.2"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 3.5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "= 3.3.0"
    }
  }
}

locals {
  kubeconfig   = abspath("${path.module}/../cluster/kubeconfig")
  kube_context = "kind-kubernetes-ai-iac"
  nginx_labels = { app = "nginx" }
}

provider "kubernetes" {
  config_path    = local.kubeconfig
  config_context = local.kube_context
}

provider "helm" {
  kubernetes = {
    config_path    = local.kubeconfig
    config_context = local.kube_context
  }
}

resource "kubernetes_namespace_v1" "web" {
  metadata {
    name = "web"
  }
}

resource "kubernetes_deployment_v1" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = local.nginx_labels
    }

    template {
      metadata {
        labels = local.nginx_labels
      }

      spec {
        container {
          name  = "nginx"
          image = "docker.io/library/nginx:1.30.8-alpine@sha256:8eb04fe3b385090e9aa02961f77398ad09b6bf33ab07f6669a5bb7acce22c0d3"

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  spec {
    type     = "ClusterIP"
    selector = local.nginx_labels

    port {
      port        = 80
      target_port = 80
    }
  }
}

resource "helm_release" "traefik" {
  name       = "traefik"
  namespace  = kubernetes_namespace_v1.web.metadata[0].name
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "43.0.0"
  skip_crds  = true

  values = [yamlencode({
    image        = { tag = "v3.8.0@sha256:00c9734983e74ae35a1fc18eaee9e9da13f3dde95c4e45b3b8c3b60e0dbd2d17" }
    service      = { spec = { type = "ClusterIP" } }
    ingressClass = { isDefaultClass = false }
    providers    = { kubernetesCRD = { enabled = false } }
    ports        = { websecure = { enabled = false } }
    api          = { dashboard = false }
  })]
}

resource "kubernetes_ingress_v1" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  spec {
    ingress_class_name = helm_release.traefik.name

    rule {
      host = "lab.motion1.de"

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.nginx.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
