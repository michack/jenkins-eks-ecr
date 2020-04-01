variable "environment" {
  type    = "map"
  default = {}
}

variable "default_tags" {
  type = "map"
}

variable "private_subnet" {
  type = "list"
}

variable "eks_node_instance_type" {
  type = "string"
}

variable "eks_node_instance_count" {
  type = "string"
}

variable "kubeconfig_path" {
  type = "string"
}
