terraform {
  required_version = ">= 1.14.0"

  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "ansible" {}
