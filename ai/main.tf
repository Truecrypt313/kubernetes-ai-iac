terraform {
  required_version = "= 1.17.2"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "= 3.5.0"
    }
  }
}

provider "kubernetes" {
  config_path    = abspath("${path.module}/../cluster/kubeconfig")
  config_context = "kind-kubernetes-ai-iac"
}

variable "models" {
  type    = set(string)
  default = ["qwen2.5:0.5b", "qwen2.5:1.5b"]
}

variable "cpu" {
  type    = string
  default = "4"
}

variable "memory" {
  type    = string
  default = "4Gi"
}

variable "storage" {
  type    = string
  default = "10Gi"
}

variable "ollama_image" {
  type    = string
  default = "docker.io/ollama/ollama@sha256:7e8c7ba387b11b09dcce1eff1118b1ab433564ed263434a7730c209f2ee346f4"
}

resource "kubernetes_namespace_v1" "ai" {
  metadata {
    name = "ai"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "ollama" {
  metadata {
    name      = "ollama-storage"
    namespace = kubernetes_namespace_v1.ai.metadata[0].name
  }

  wait_until_bound = false

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "standard"

    resources {
      requests = {
        storage = var.storage
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "kubernetes_deployment_v1" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace_v1.ai.metadata[0].name
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = { app = "ollama" }
    }

    template {
      metadata {
        labels = { app = "ollama" }
      }

      spec {
        automount_service_account_token = false
        enable_service_links            = false

        container {
          name              = "ollama"
          image             = var.ollama_image
          image_pull_policy = "IfNotPresent"

          port {
            container_port = 11434
          }

          resources {
            requests = {
              cpu    = "2"
              memory = "2Gi"
            }
            limits = {
              cpu    = var.cpu
              memory = var.memory
            }
          }

          readiness_probe {
            http_get {
              path = "/api/tags"
              port = 11434
            }
          }

          volume_mount {
            name       = "models"
            mount_path = "/root/.ollama"
          }
        }

        volume {
          name = "models"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.ollama.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "ollama" {
  metadata {
    name      = "ollama"
    namespace = kubernetes_namespace_v1.ai.metadata[0].name
  }

  spec {
    selector = { app = "ollama" }
    type     = "ClusterIP"

    port {
      port        = 11434
      target_port = 11434
    }
  }
}

resource "kubernetes_job_v1" "model_pull" {
  for_each = var.models

  metadata {
    name      = "pull-${substr(sha256(each.value), 0, 12)}"
    namespace = kubernetes_namespace_v1.ai.metadata[0].name
  }

  wait_for_completion = true

  spec {
    backoff_limit           = 3
    active_deadline_seconds = 900

    template {
      metadata {}

      spec {
        restart_policy                  = "Never"
        automount_service_account_token = false
        enable_service_links            = false

        container {
          name              = "model-puller"
          image             = var.ollama_image
          image_pull_policy = "IfNotPresent"
          command           = ["ollama", "pull"]
          args              = [each.value]

          env {
            name  = "OLLAMA_HOST"
            value = "http://${kubernetes_service_v1.ollama.metadata[0].name}:11434"
          }
        }
      }
    }
  }

  timeouts {
    create = "20m"
  }

  depends_on = [kubernetes_deployment_v1.ollama]
}
