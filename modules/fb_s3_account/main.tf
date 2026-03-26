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

locals {
  playbook_base_path = "${var.project_root}/ansible-fb/playbooks"
  ansible_bin        = "${var.project_root}/ansible_env/bin/ansible-playbook"
  ansible_python     = "${var.project_root}/ansible_env/bin/python3"
  collections_path   = "${var.project_root}/ansible_env/lib/python3.12/site-packages/ansible_collections"
  python_path        = "${var.project_root}/ansible_env/lib/python3.12/site-packages"
}

# Apply / reconcile: runs on every terraform apply (replayable = true).
# purefb_s3acc is idempotent — it creates if absent, updates if config differs,
# and makes no change if the account already matches desired state.
resource "ansible_playbook" "s3_account" {
  playbook   = "${local.playbook_base_path}/s3_account_apply.yml"
  name       = "localhost"
  replayable = true

  extra_vars = {
    fb_url                     = var.fb_url
    api_token                  = var.api_token
    account_name               = var.account_name
    quota                      = var.quota
    hard_limit                 = tostring(var.hard_limit)
    ansible_python_interpreter = local.ansible_python
  }
}

# Destroy: runs s3_account_destroy.yml when terraform destroy is called.
# All values needed at destroy time are stored in triggers (persisted in state).
# api_token sensitivity is auto-propagated from var.api_token.
# Credentials are passed via PUREFB_URL / PUREFB_API env vars to avoid CLI exposure.
resource "null_resource" "s3_account_destroy" {
  triggers = {
    account_name    = var.account_name
    fb_url          = var.fb_url
    api_token       = var.api_token
    playbook_path   = "${local.playbook_base_path}/s3_account_destroy.yml"
    ansible_bin     = local.ansible_bin
    collections_path = local.collections_path
    python_path     = local.python_path
  }

  provisioner "local-exec" {
    when    = destroy
    command = "${self.triggers.ansible_bin} ${self.triggers.playbook_path} -i localhost, -c local -e account_name=${self.triggers.account_name}"

    environment = {
      PUREFB_URL                = self.triggers.fb_url
      PUREFB_API                = self.triggers.api_token
      ANSIBLE_COLLECTIONS_PATHS = self.triggers.collections_path
      PYTHONPATH                = self.triggers.python_path
    }
  }

  depends_on = [ansible_playbook.s3_account]
}
