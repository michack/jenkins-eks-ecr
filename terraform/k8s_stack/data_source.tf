data "terraform_remote_state" "eks_stack" {
  backend = "s3"
  config = {
    bucket = "${var.bucket_name}"
    key    = "aws-eks/eks-stack.tfstate"
    region = "us-west-2"
  }
}
