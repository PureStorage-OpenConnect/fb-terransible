variable "fb_url" {
  description = "FlashBlade management IP address or hostname."
  type        = string
}

variable "api_token" {
  description = "FlashBlade API token. Set via terraform.tfvars or TF_VAR_api_token env var."
  type        = string
  sensitive   = true
}

variable "s3_account_name" {
  description = "Name of the S3 object store account to create/manage."
  type        = string
  default     = "myaccount"
}

variable "s3_account_quota" {
  description = "Quota for the S3 account (e.g. '500G'). Empty string for unlimited."
  type        = string
  default     = ""
}

variable "s3_account_hard_limit" {
  description = "Enforce account quota as a hard limit."
  type        = bool
  default     = false
}

variable "buckets" {
  description = "Map of bucket names to their configuration."
  type = map(object({
    versioning = optional(string, "absent")
    quota      = optional(string, "")
    hard_limit = optional(bool, false)
    eradicate  = optional(bool, false)
  }))
  default = {}
}

variable "project_root" {
  description = "Absolute path to the project root directory. Defaults to two levels above envs/dev/."
  type        = string
  default     = ""
}
