variable "environment" {
  type    = "map"
  default = {}
}

variable "default_tags" {
  type = "map"
}

variable "bucket_name" {
  type = "string"
}

variable "jenkins_docker_url" {
  type = "string"
}
