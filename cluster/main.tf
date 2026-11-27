terraform {
  required_version = "= 1.17.2"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "= 0.13.0"
    }
  }
}

provider "kind" {}

resource "kind_cluster" "lab" {
  name            = "kubernetes-ai-iac"
  node_image      = "kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0"
  kubeconfig_path = "${path.module}/kubeconfig"
  wait_for_ready  = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      api_server_address = "127.0.0.1"
    }

    node {
      role = "control-plane"
    }
  }
}
