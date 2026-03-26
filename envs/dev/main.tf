module "s3_account" {
  source = "../../modules/fb_s3_account"

  fb_url       = var.fb_url
  api_token    = var.api_token
  account_name = var.s3_account_name
  quota        = var.s3_account_quota
  hard_limit   = var.s3_account_hard_limit

  playbook_base_path = var.playbook_base_path
}

module "s3_bucket" {
  for_each = var.buckets
  source   = "../../modules/fb_bucket"

  fb_url       = var.fb_url
  api_token    = var.api_token
  bucket_name  = each.key
  account_name = var.s3_account_name
  versioning   = each.value.versioning
  quota        = each.value.quota
  hard_limit   = each.value.hard_limit
  eradicate    = each.value.eradicate

  playbook_base_path = var.playbook_base_path

  depends_on = [module.s3_account]
}
