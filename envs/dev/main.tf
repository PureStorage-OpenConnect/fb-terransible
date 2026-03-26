locals {
  project_root = var.project_root != "" ? var.project_root : abspath("${path.root}/../..")
}

module "s3_account" {
  source = "../../modules/fb_s3_account"

  fb_url       = var.fb_url
  api_token    = var.api_token
  account_name = var.s3_account_name
  quota        = var.s3_account_quota
  hard_limit   = var.s3_account_hard_limit

  project_root = local.project_root
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

  project_root = local.project_root

  depends_on = [module.s3_account]
}
