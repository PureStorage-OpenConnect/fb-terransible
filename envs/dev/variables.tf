variable "fb_url" {
  description = "FlashBlade management IP address or hostname."
  type        = string
}

variable "api_token" {
  description = "FlashBlade API token. Set via terraform.tfvars or TF_VAR_api_token env var."
  type        = string
  sensitive   = true
}

variable "s3_accounts" {
  description = "Map of S3 object store account names to their configuration."
  type = map(object({
    quota      = optional(string, "")
    hard_limit = optional(bool, false)
  }))
  default = {}
}

variable "buckets" {
  description = "Map of bucket names to their configuration. account_name must reference a key in s3_accounts."
  type = map(object({
    account_name = string
    versioning   = optional(string, "absent")
    quota        = optional(string, "")
    hard_limit   = optional(bool, false)
    eradicate    = optional(bool, false)
  }))
  default = {}
}

variable "project_root" {
  description = "Absolute path to the project root directory. Defaults to two levels above envs/dev/."
  type        = string
  default     = ""
}
