resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.environment["name"]}-eks"
  role_arn = "${aws_iam_role.eks_cluster.arn}"

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids              = "${aws_subnet.private_subnet.*.id}"
    security_group_ids      = ["${aws_security_group.eks_cluster.id}"]
  }

  tags = "${var.default_tags}"

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    "aws_iam_role_policy_attachment.AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.AmazonEKSServicePolicy",
  ]
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.environment["name"]}-eks"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role = "${aws_iam_role.eks_cluster.name}"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role = "${aws_iam_role.eks_cluster.name}"
}

resource "aws_iam_role_policy" "eks_access_elb" {
  name = "${var.environment["name"]}-eks-access-elb"
  role = "${aws_iam_role.eks_cluster.name}"
  policy = <<-EOF
  {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "iam:CreateServiceLinkedRole",
                "Resource": "arn:aws:iam::*:role/aws-service-role/*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:DescribeAccountAttributes"
                ],
                "Resource": "*"
            }
        ]
  }
  EOF
}

resource "aws_security_group" "eks_cluster" {
  name   = "${var.environment["name"]}-eks-sg"
  vpc_id = "${aws_vpc.env_vpc.id}"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = "${var.default_tags}"
}

# create kubeconfig file
resource "null_resource" "kubeconfig" {
  provisioner "local-exec" {
    command = <<KUBECONFIG
echo '
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.eks_cluster.certificate_authority.0.data}
    server: ${aws_eks_cluster.eks_cluster.endpoint}
  name: ${aws_eks_cluster.eks_cluster.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.eks_cluster.arn}
    user: ${aws_eks_cluster.eks_cluster.arn}
  name: ${aws_eks_cluster.eks_cluster.arn}
current-context: ${aws_eks_cluster.eks_cluster.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.eks_cluster.arn}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - --region
      - us-west-2
      - eks
      - get-token
      - --cluster-name
      - ${aws_eks_cluster.eks_cluster.name}
      command: aws
' > ${var.kubeconfig_path}
KUBECONFIG
  }
}
