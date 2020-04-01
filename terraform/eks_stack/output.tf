output "eks_cluster_url" {
  value = "${aws_eks_cluster.eks_cluster.endpoint}"
}

output "eks_cluster_name" {
  value = "${aws_eks_cluster.eks_cluster.name}"
}

output "kubeconfig-certificate-authority-data" {
  value = "${aws_eks_cluster.eks_cluster.certificate_authority.0.data}"
}

output "ecr_repository_url" {
  value = "${aws_ecr_repository.ecr.repository_url}"
}

output "ecr_repository_name" {
  value = "${aws_ecr_repository.ecr.name}"
}

output "private_subnets_ids" {
  value = "${aws_subnet.private_subnet.*.id}"
}
