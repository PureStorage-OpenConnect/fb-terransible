variable "fb_url" {
  description = "FlashBlade management IP address or hostname."
  type        = string
}

variable "api_token" {
  description = "FlashBlade API token."
  type        = string
  sensitive   = true
}

variable "account_name" {
  description = "Name of the S3 object store account to create/manage."
  type        = string
}

variable "quota" {
  description = "Effective quota limit for the account (e.g. '10G', '500M'). Empty string for unlimited."
  type        = string
  default     = ""
}

variable "hard_limit" {
  description = "If true, enforce the quota as a hard limit."
  type        = bool
  default     = false
}

variable "playbook_base_path" {
  description = "Absolute path to the ansible-fb/playbooks directory."
  type        = string
  default     = "/home/egrosso/fb-terransible/ansible-fb/playbooks"
}
