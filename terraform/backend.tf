terraform {
  backend "s3" {
    bucket = "meekail-fem-infra"
    key = "terraform.tfstate"
    region = "us-west-2"
  }
}