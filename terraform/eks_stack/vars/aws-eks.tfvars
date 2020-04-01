environment = {
    name       = "aws-eks"
    vpc_cidr   = "10.11.0.0/16"
    region     = "us-west-2"
}

default_tags = {
    environment = "aws-eks"
}

private_subnet = ["10.11.2.0/24", "10.11.3.0/24"]

# eks nodes instances:
eks_node_instance_type  = "t2.micro"
eks_node_instance_count = 2

# terraform will create kubeconfig for EKS and store it under the path:
kubeconfig_path = "/tmp/kubeconfig_eks.txt"
