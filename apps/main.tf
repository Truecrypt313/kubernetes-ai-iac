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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "= 5.29.0"
    }
  }
}

variable "cloudflare_account_id" {
  description = "Cloudflare-Konto, in dem der Tunnel erstellt wird."
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare-Zone für motion1.de im selben Konto wie der Tunnel."
  type        = string
  sensitive   = true
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

provider "cloudflare" {}

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

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "monitoring" {
  name       = "monitoring"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "94.1.0"

  values = [yamlencode({
    alertmanager       = { enabled = false }
    defaultRules       = { rules = { alertmanager = false } }
    prometheusOperator = { enabled = true }
    nodeExporter       = { enabled = true }
    kubeStateMetrics   = { enabled = true }

    prometheus = {
      enabled        = true
      ingress        = { enabled = false }
      service        = { type = "ClusterIP" }
      prometheusSpec = { retention = "24h" }
    }

    grafana = {
      enabled = true
      ingress = { enabled = false }
      service = { type = "ClusterIP" }
    }

    # Diese Metrik-Endpunkte sind in kind nur auf Loopback gebunden.
    kubeEtcd              = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeProxy             = { enabled = false }
  })]
}

resource "kubernetes_service_account_v1" "codex_mcp" {
  metadata {
    name      = "codex-mcp"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  automount_service_account_token = false
}

resource "kubernetes_cluster_role_v1" "codex_mcp" {
  metadata {
    name = "codex-mcp-read-only"
  }

  rule {
    api_groups = [""]
    resources  = ["events", "pods", "services"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["daemonsets", "deployments", "statefulsets"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding_v1" "codex_mcp" {
  for_each = {
    web        = kubernetes_namespace_v1.web.metadata[0].name
    monitoring = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  metadata {
    name      = "codex-mcp-read-only"
    namespace = each.value
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.codex_mcp.metadata[0].name
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.codex_mcp.metadata[0].name
    namespace = kubernetes_service_account_v1.codex_mcp.metadata[0].namespace
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "lab" {
  account_id = var.cloudflare_account_id
  name       = "kubernetes-ai-iac"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "lab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.lab.id

  config = {
    ingress = [
      {
        hostname = kubernetes_ingress_v1.nginx.spec[0].rule[0].host
        service  = "http://${helm_release.traefik.name}.${helm_release.traefik.namespace}.svc.cluster.local:80"
      },
      { service = "http_status:404" }
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "lab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.lab.id
}

resource "kubernetes_secret_v1" "cloudflared" {
  metadata {
    name      = "cloudflared-tunnel"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  type             = "Opaque"
  data_wo          = { token = data.cloudflare_zero_trust_tunnel_cloudflared_token.lab.token }
  data_wo_revision = 1
}

resource "kubernetes_deployment_v1" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace_v1.web.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "cloudflared" }
    }

    template {
      metadata {
        labels = { app = "cloudflared" }
      }

      spec {
        automount_service_account_token = false

        container {
          name  = "cloudflared"
          image = "docker.io/cloudflare/cloudflared:2026.11.2@sha256:55c7e3e8d89d5e8d20b75a82f3602cbf98e06db406e73e282073cfdc5a9a3af6"
          args  = ["tunnel", "--no-autoupdate", "--metrics", "0.0.0.0:2000", "run", "--token-file", "/etc/cloudflared/token"]

          volume_mount {
            name       = "tunnel-token"
            mount_path = "/etc/cloudflared"
            read_only  = true
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 2000
            }
          }
        }

        volume {
          name = "tunnel-token"
          secret {
            secret_name  = kubernetes_secret_v1.cloudflared.metadata[0].name
            default_mode = "0444"
          }
        }
      }
    }
  }

  depends_on = [cloudflare_zero_trust_tunnel_cloudflared_config.lab]
}

resource "cloudflare_dns_record" "lab" {
  zone_id = var.cloudflare_zone_id
  name    = kubernetes_ingress_v1.nginx.spec[0].rule[0].host
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.lab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1

  depends_on = [kubernetes_deployment_v1.cloudflared]
}
