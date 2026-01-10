variable "bastion_ingress" {
  default = []
  description = "CIDR block for bastion ingress"
  type = list(string)
}

variable "name" {
  description = "Name of the cloud enviornment"
  type = string
}
