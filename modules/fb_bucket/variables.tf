variable "fb_url" {
  description = "FlashBlade management IP address or hostname."
  type        = string
}

variable "api_token" {
  description = "FlashBlade API token."
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Name of the S3 bucket to create/manage."
  type        = string
}

variable "account_name" {
  description = "Name of the S3 object store account this bucket belongs to."
  type        = string
}

variable "versioning" {
  description = "S3 bucket versioning state."
  type        = string
  default     = "absent"

  validation {
    condition     = contains(["absent", "enabled", "suspended"], var.versioning)
    error_message = "versioning must be one of: absent, enabled, suspended."
  }
}

variable "quota" {
  description = "Effective quota limit for the bucket (e.g. '10G', '500M'). Empty string for unlimited."
  type        = string
  default     = ""
}

variable "hard_limit" {
  description = "If true, enforce the quota as a hard limit."
  type        = bool
  default     = false
}

variable "eradicate" {
  description = "If true, permanently eradicate the bucket on destroy. If false, leave in trash (recoverable)."
  type        = bool
  default     = false
}

variable "playbook_base_path" {
  description = "Absolute path to the ansible-fb/playbooks directory."
  type        = string
  default     = "/home/egrosso/fb-tfansible/ansible-fb/playbooks"
}
