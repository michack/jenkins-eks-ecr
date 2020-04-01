resource "kubernetes_persistent_volume" "jenkins" {
  metadata {
    name = "jenkins"
    labels = {
      type = "local"
    }
  }
  spec {
    storage_class_name = "gp2"
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/data/jenkins/"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "jenkins" {
  metadata {
    name = "jenkins-claim"
  }
  spec {
    storage_class_name = "gp2"
    access_modes       = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
    volume_name = "${kubernetes_persistent_volume.jenkins.metadata.0.name}"
  }
}

resource "kubernetes_service_account" "jenkins" {
  metadata {
    name = "jenkins"
  }
  automount_service_account_token = "true"
}

resource "kubernetes_cluster_role_binding" "jenkins-cluster-admin" {
  metadata {
    name = "jenkins-cluster-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = "default"
  }
}

resource "kubernetes_config_map" "init-script" {
  metadata {
    name = "init-script"
  }

  data = {
    init-script = <<EOF
      #!/bin/bash -v
      apk add --update \
        python \
        python-dev \
        py-pip \
        build-base \
        git \
        jq \
        && pip install awscli --upgrade --user \
        && apk --purge -v del py-pip \
        && rm -rf /var/cache/apk/*
      ln -s /root/.local/bin/aws /usr/bin/aws

      JENKINS_IMAGE=$(aws ecr list-images --region=us-west-2 --repository-name ${data.terraform_remote_state.eks_stack.outputs.ecr_repository_name} | jq -c .imageIds[] | grep -c '"imageTag":"jenkins"')
      if [ $JENKINS_IMAGE -ne 1 ]; then
        docker build --network=host ${var.jenkins_docker_url} -t jenkins
        docker tag jenkins ${data.terraform_remote_state.eks_stack.outputs.ecr_repository_url}:jenkins
        aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin ${data.terraform_remote_state.eks_stack.outputs.ecr_repository_url}
        docker push ${data.terraform_remote_state.eks_stack.outputs.ecr_repository_url}:jenkins
      else
        echo "Jenkins image already exists"
      fi
  EOF
  }
}

resource "kubernetes_service" "jenkins" {
  metadata {
    name = "jenkins"
    labels = {
      app = "jenkins"
    }
    #    annotations = {
    #      "service.beta.kubernetes.io/aws-load-balancer-internal" = "${data.terraform_remote_state.eks_stack.outputs.subnets.ids[0]}"
    #    }
  }
  spec {
    selector = {
      app = "jenkins"
      tier = "jenkins"
    }
    port {
      port = 8080
      target_port = 8080
    }
    type = "LoadBalancer"
  }
}


resource "kubernetes_deployment" "jenkins" {
  metadata {
    name = "jenkins"
    labels = {
      app = "jenkins"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "jenkins"
      }
    }
    strategy {
      type = "Recreate"
    }
    template {
      metadata {
        labels = {
          app = "jenkins"
          tier = "jenkins"
        }
      }
      spec {
        service_account_name = "${kubernetes_service_account.jenkins.metadata.0.name}"
        automount_service_account_token = "true"
        init_container {
          image = "docker"
          name = "init-script"
          command = ["/bin/sh"]
          args = ["/init-script.sh"]
          volume_mount {
            mount_path = "/var/run/docker.sock"
            name = "docker"
          }
          volume_mount {
            mount_path = "/init-script.sh"
            name = "init-script"
            sub_path = "init-script.sh"
          }
        }
        container {
          image = "${data.terraform_remote_state.eks_stack.outputs.ecr_repository_url}:jenkins"
          name = "jenkins"
          env {
            name = "ECR_REPO_URL"
            value = "${data.terraform_remote_state.eks_stack.outputs.ecr_repository_url}"
          }
          env {
            name = "ECR_REGION"
            value = "us-west-2"
          }
          security_context {
            privileged = "true"
          }
          volume_mount {
            mount_path = "/var/run/docker.sock"
            name = "docker"
          }
          volume_mount {
            mount_path = "/var/jenkins_home"
            name = "jenkins-persistent-storage"
          }
          port { container_port = "8080" }
        }
        volume {
          name = "init-script"
          config_map {
            name = "init-script"
            items {
              key = "init-script"
              path = "init-script.sh"
            }
          }
        }
        volume {
          name = "docker"
          host_path {
            path = "/var/run/docker.sock"
          }
        }
        volume {
          name = "jenkins-persistent-storage"
          persistent_volume_claim {
            claim_name = "${kubernetes_persistent_volume_claim.jenkins.metadata.0.name}"
          }
        }
      }
    }
  }
}
