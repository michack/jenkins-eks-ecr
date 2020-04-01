
#
# EKS Worker Nodes Resources
#  * IAM role allowing Kubernetes actions to access other AWS services
#  * EKS Node Group to launch worker nodes
#

resource "aws_iam_role" "eks-node" {
  name               = "${var.environment["name"]}-eks-node"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role = "${aws_iam_role.eks-node.name}"
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role = "${aws_iam_role.eks-node.name}"
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = "${aws_iam_role.eks-node.name}"
}

resource "aws_iam_role_policy_attachment" "eks-node-AmazonEC2ContainerRegistryPowerUser" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
  role = "${aws_iam_role.eks-node.name}"
}

# EKS nodes access to ECR
# https://docs.aws.amazon.com/AmazonECR/latest/userguide/ECR_on_EKS.html
resource "aws_iam_role_policy" "eks_node_access_ecr" {
  name = "${var.environment["name"]}-eks-node-access-ecr"
  role = "${aws_iam_role.eks-node.id}"

  policy = <<-EOF
  {
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "ecr:BatchCheckLayerAvailability",
                  "ecr:BatchGetImage",
                  "ecr:GetDownloadUrlForLayer",
                  "ecr:GetAuthorizationToken"
              ],
              "Resource": "*"
          }
      ]
  }
  EOF
}

resource "aws_eks_node_group" "eks" {
  cluster_name    = "${aws_eks_cluster.eks_cluster.name}"
  node_group_name = "${var.environment["name"]}-eks"
  node_role_arn   = "${aws_iam_role.eks-node.arn}"
  subnet_ids      = "${aws_subnet.private_subnet.*.id}"
  scaling_config {
    desired_size = "${var.eks_node_instance_count}"
    max_size     = "${var.eks_node_instance_count}"
    min_size     = "${var.eks_node_instance_count}"
  }
  ami_type       = "AL2_x86_64"
  disk_size      = "20"
  instance_types = ["${var.eks_node_instance_type}"]
  tags           = "${var.default_tags}"
  depends_on = [
    "aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy",
    "aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy",
    "aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly",
    "aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryPowerUser",
  ]
}

resource "aws_security_group" "eks_node_access" {
  name   = "${var.environment["name"]}-eks-node-sg"
  vpc_id = "${aws_vpc.env_vpc.id}"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = "${var.default_tags}"
}
