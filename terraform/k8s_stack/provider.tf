provider "kubernetes" {
  load_config_file       = "false"
  host                   = "${data.terraform_remote_state.eks_stack.outputs.eks_cluster_url}"
  cluster_ca_certificate = "${base64decode(data.terraform_remote_state.eks_stack.outputs.kubeconfig-certificate-authority-data)}"
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws"
    args        = ["--region", "us-west-2", "eks", "get-token", "--cluster-name", "${data.terraform_remote_state.eks_stack.outputs.eks_cluster_name}"]
  }
}
