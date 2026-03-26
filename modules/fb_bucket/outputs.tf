output "bucket_name" {
  description = "The name of the managed S3 bucket."
  value       = var.bucket_name
}

output "account_name" {
  description = "The S3 object store account this bucket belongs to."
  value       = var.account_name
}
