# fb-tfansible

Terraform wrapper for managing Pure Storage FlashBlade S3 objects (accounts and buckets) via Ansible.

The project introduces **stateful management** on top of Ansible's inherently stateless nature by using Terraform to track resource state. Every `terraform apply` re-executes the underlying Ansible playbooks, which are idempotent — they reconcile the real FlashBlade state to match the desired configuration, handling any drift transparently.

---

## How it works

```
terraform apply / destroy
        │
        ▼
ansible/ansible Terraform provider
        │
        ▼
ansible-playbook  (purestorage.flashblade collection)
        │
        ▼
FlashBlade HTTP API  (fb_url + api_token)
```

- **`terraform apply`** → runs `bucket_apply.yml` / `s3_account_apply.yml` with `state: present`.
  Because `replayable = true`, the playbooks run on *every* apply — not only on first create.
  This is the drift reconciliation mechanism.
- **`terraform destroy`** → triggers destroy provisioners that run `bucket_destroy.yml` /
  `s3_account_destroy.yml` with `state: absent`. Buckets are soft-deleted by default
  (`eradicate = false`) and can be recovered from the appliance trash.

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Terraform | ≥ 1.14 | Available at `/usr/bin/terraform` |
| Python | 3.12 | Included in `ansible_env/` |
| Ansible | 2.20 (core) | Included in `ansible_env/` |
| purestorage.flashblade | 1.24.0 | Installed in `ansible_env/` |

The Python virtual environment (`ansible_env/`) must be present at the repo root. It is **not**
tracked in git and must be created separately (see [Setup](#setup)).

---

## Project structure

```
fb-tfansible/
├── ansible-fb/
│   ├── ansible.cfg                  # Collections path, Python interpreter
│   ├── inventories/
│   │   └── flashblade.yml           # localhost inventory (connection: local)
│   └── playbooks/
│       ├── s3_account_apply.yml
│       ├── s3_account_destroy.yml
│       ├── bucket_apply.yml
│       └── bucket_destroy.yml
│
├── modules/
│   ├── fb_s3_account/               # Terraform module — S3 object store account
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── fb_bucket/                   # Terraform module — S3 bucket
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── envs/
    └── dev/
        ├── providers.tf             # Provider declarations
        ├── variables.tf
        ├── main.tf                  # Module instantiation
        └── terraform.tfvars.example # Credentials/config template
```

---

## Setup

### 1. Recreate the Python virtual environment

```bash
python3 -m venv ansible_env
source ansible_env/bin/activate
pip install ansible
pip install -r ansible_env/lib/python3.12/site-packages/ansible_collections/purestorage/flashblade/requirements.txt
```

Note that the Everpure ansible galaxy collections are installed by default with ansible, so there is not any need of executing `ansible-galaxy collection install purestorage.flashblade`.

### 2. Configure credentials

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your FlashBlade details:

```hcl
fb_url    = "10.10.10.2"           # FlashBlade management IP or hostname
api_token = "T-xxxxxxxx-xxxx-..."  # API token (Settings > API Tokens on the FlashBlade UI)
```

### 3. Initialise Terraform

```bash
# Required before every session:
source /path/to/repo/ansible_env/bin/activate
export ANSIBLE_CONFIG=/path/to/repo/ansible-fb/ansible.cfg

cd envs/dev
terraform init
```

---

## Example: create an account and two buckets

Edit `envs/dev/terraform.tfvars`:

```hcl
fb_url          = "10.10.10.2"
api_token       = "T-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
s3_account_name = "myteam"

buckets = {
  "logs-bucket" = {
    versioning = "enabled"
    quota      = "200G"
    hard_limit = false
    eradicate  = false
  }
  "backups-bucket" = {
    versioning = "absent"
    quota      = "500G"
    hard_limit = true
    eradicate  = false
  }
}
```

Then run:

```bash
# Preview changes
terraform plan

# Apply — creates account 'myteam', then both buckets
terraform apply
```

Expected output (abbreviated):

```
module.s3_account.ansible_playbook.s3_account: Creating...
module.s3_account.ansible_playbook.s3_account: Creation complete
module.s3_bucket["logs-bucket"].ansible_playbook.bucket: Creating...
module.s3_bucket["backups-bucket"].ansible_playbook.bucket: Creating...
...
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

---

## Drift reconciliation test

1. Manually delete `logs-bucket` directly on the FlashBlade appliance (or via the UI).
2. Run `terraform apply` again — no changes to `terraform.tfvars` needed.
3. Terraform re-runs all playbooks (`replayable = true`). `purefb_bucket` detects the bucket
   is missing and re-creates it automatically.

---

## Destroy

```bash
# Soft-delete buckets (recoverable from FlashBlade trash), then delete account
terraform destroy
```

To permanently eradicate a bucket on destroy, set `eradicate = true` in `terraform.tfvars`
before running `terraform destroy`.

---

## Adding a new environment

```bash
cp -r envs/dev envs/staging
# Edit envs/staging/terraform.tfvars with staging FlashBlade credentials
cd envs/staging
terraform init
terraform apply
```

---

## Sensitive data

`api_token` is declared `sensitive = true` in all Terraform variables. Terraform redacts it in
plan/apply output. `terraform.tfvars` is gitignored. Never commit real credentials.
