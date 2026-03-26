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
# purefb_s3acc is idempotent — it creates if absent, updates if config differs,
# and makes no change if the account already matches desired state.
resource "ansible_playbook" "s3_account" {
  playbook   = "${var.playbook_base_path}/s3_account_apply.yml"
  name       = "localhost"
  replayable = true

  extra_vars = {
    fb_url       = var.fb_url
    api_token    = var.api_token
    account_name = var.account_name
    quota        = var.quota
    hard_limit   = tostring(var.hard_limit)
  }
}

# Destroy: runs s3_account_destroy.yml when terraform destroy is called.
# All values needed at destroy time are stored in triggers (persisted in state).
# api_token sensitivity is auto-propagated from var.api_token.
# Credentials are passed via PUREFB_URL / PUREFB_API env vars to avoid CLI exposure.
resource "null_resource" "s3_account_destroy" {
  triggers = {
    account_name  = var.account_name
    fb_url        = var.fb_url
    api_token     = var.api_token
    playbook_path = "${var.playbook_base_path}/s3_account_destroy.yml"
    ansible_bin   = "/home/egrosso/fb-terransible/ansible_env/bin/ansible-playbook"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${self.triggers.ansible_bin} ${self.triggers.playbook_path} -i localhost, -c local -e account_name=${self.triggers.account_name}"

    environment = {
      PUREFB_URL                = self.triggers.fb_url
      PUREFB_API                = self.triggers.api_token
      ANSIBLE_COLLECTIONS_PATHS = "/home/egrosso/fb-terransible/ansible_env/lib/python3.12/site-packages/ansible_collections"
      PYTHONPATH                = "/home/egrosso/fb-terransible/ansible_env/lib/python3.12/site-packages"
    }
  }

  depends_on = [ansible_playbook.s3_account]
}
