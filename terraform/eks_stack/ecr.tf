resource "aws_ecr_repository" "ecr" {
  name = "${var.environment["name"]}-repo"
}
