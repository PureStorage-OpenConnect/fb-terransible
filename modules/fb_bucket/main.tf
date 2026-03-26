terraform {
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

# Apply / reconcile: runs on every terraform apply (replayable = true).
# purefb_bucket is idempotent — creates if absent, updates config if it differs,
# no-ops if bucket already matches desired state. This is the drift reconciliation mechanism.
resource "ansible_playbook" "bucket" {
  playbook   = "${var.playbook_base_path}/bucket_apply.yml"
  name       = "localhost"
  replayable = true

  extra_vars = {
    fb_url       = var.fb_url
    api_token    = var.api_token
    bucket_name  = var.bucket_name
    account_name = var.account_name
    versioning   = var.versioning
    quota        = var.quota
    hard_limit   = tostring(var.hard_limit)
  }
}

# Destroy: runs bucket_destroy.yml when terraform destroy is called.
# All values needed at destroy time are stored in triggers (persisted in state).
# eradicate is stored as string; the playbook coerces it back with | bool.
# Credentials are passed via PUREFB_URL / PUREFB_API env vars to avoid CLI exposure.
resource "null_resource" "bucket_destroy" {
  triggers = {
    bucket_name   = var.bucket_name
    account_name  = var.account_name
    eradicate     = tostring(var.eradicate)
    fb_url        = var.fb_url
    api_token     = var.api_token
    playbook_path = "${var.playbook_base_path}/bucket_destroy.yml"
    ansible_bin   = "/home/egrosso/fb-terransible/ansible_env/bin/ansible-playbook"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${self.triggers.ansible_bin} ${self.triggers.playbook_path} -i localhost, -c local -e \"bucket_name=${self.triggers.bucket_name} account_name=${self.triggers.account_name} eradicate=${self.triggers.eradicate}\""

    environment = {
      PUREFB_URL                = self.triggers.fb_url
      PUREFB_API                = self.triggers.api_token
      ANSIBLE_COLLECTIONS_PATHS = "/home/egrosso/fb-terransible/ansible_env/lib/python3.12/site-packages/ansible_collections"
      PYTHONPATH                = "/home/egrosso/fb-terransible/ansible_env/lib/python3.12/site-packages"
    }
  }

  depends_on = [ansible_playbook.bucket]
}
