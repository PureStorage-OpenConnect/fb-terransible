# FB TerrAnsible

> ## Disclaimer and Trademark Usage Policy

### 1. General Disclaimer
This project is provided **solely as an example** and is not supported, endorsed, or recommended by **Everpure**. Users are free to choose any automation tool for deploying and managing Everpure (formerly Pure Storage) appliances; however, Everpure does not recommend using Terraform for this purpose. 

The only officially supported automation approaches are **Pure Storage Ansible Collections** and direct use of the **Pure Storage REST APIs** and officially provided **SDKs**. Use this code at your own risk.

### 2. Trademark and Copyright Compliance
The names "Everpure," "Pure Storage," "Purity," "Portworx," and all associated logos are trademarks or registered trademarks of Everpure, Inc. 

If you choose to develop, fork, or publish your own Terraform provider or any derivative software based on this repository, you must adhere to the following naming and branding requirements:

*   **No Infringing Names:** You may **not** use "Everpure" or "Pure Storage" as the leading word or primary brand for your project.
    *   **Prohibited:** `terraform-provider-everpure`, `Everpure-Provisioner`, `PureStorage-Terraform`
    *   **Permitted:** `terraform-provider-community-for-everpure`, `example-provider-pure-storage`
*   **No Implied Affiliation:** Your project documentation must clearly and prominently state that it is a "third-party community project" and is **not** affiliated with, sponsored by, or endorsed by Everpure.
*   **No Logo Usage:** You are strictly prohibited from using any official Everpure or Pure Storage logos, icons, or visual branding elements in your repository or published software.
*   **Descriptive Use Only:** You may use Everpure trademarks only in a descriptive capacity (e.g., "This tool is designed to interface with Everpure appliances") and never as a brand identifier for your own work.

### 3. Liability
By using, modifying, or publishing any code based on this repository, you acknowledge that you are solely responsible for ensuring your project does not infringe upon the intellectual property rights of Everpure. The authors of this repository accept no liability for any legal actions arising from your use of trademarked terms or copyrighted materials.
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
fb-terransible/
├── ansible-fb/
│   ├── ansible.cfg                  # Python interpreter, retry settings
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
│   │   └── variables.tf
│   └── fb_bucket/                   # Terraform module — S3 bucket
│       ├── main.tf
│       └── variables.tf
│
├── scripts/
│   └── generate_tfvars.py           # Queries FlashBlade and generates terraform.tfvars
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

## Example: create accounts and buckets

Edit `envs/dev/terraform.tfvars`:

```hcl
fb_url    = "10.10.10.2"
api_token = "T-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

s3_accounts = {
  "myteam" = {
    quota      = "1T"
    hard_limit = false
  }
}

buckets = {
  "logs-bucket" = {
    account_name = "myteam"
    versioning   = "enabled"
    quota        = "200G"
  }
  "backups-bucket" = {
    account_name = "myteam"
    quota        = "500G"
    hard_limit   = true
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
module.s3_account["myteam"].ansible_playbook.s3_account: Creating...
module.s3_account["myteam"].ansible_playbook.s3_account: Creation complete
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

## Importing existing FlashBlade resources

If you already have S3 accounts and buckets on your FlashBlade, you can import them into
Terraform state instead of declaring them manually.

### 1. Generate terraform.tfvars from FlashBlade

```bash
source ansible_env/bin/activate

# Import all accounts and their buckets:
python3 scripts/generate_tfvars.py --fb-url 10.225.112.185 --api-token T-xxx

# Filter to specific accounts:
python3 scripts/generate_tfvars.py --fb-url 10.225.112.185 --api-token T-xxx \
  --account myteam --account otherteam

# Write directly to the environment tfvars file:
python3 scripts/generate_tfvars.py --fb-url 10.225.112.185 --api-token T-xxx \
  -o envs/dev/terraform.tfvars

# Or use environment variables instead of flags:
export PUREFB_URL=10.225.112.185
export PUREFB_API=T-xxx
python3 scripts/generate_tfvars.py -o envs/dev/terraform.tfvars
```

The script queries the FlashBlade API directly and outputs valid `terraform.tfvars` syntax,
including all accounts with their quota settings, and all non-destroyed buckets with their
versioning, quota, and account association.

### 2. Add credentials and apply

Add `fb_url` and `api_token` to the generated `terraform.tfvars` (the script does not include
credentials for security), then:

```bash
cd envs/dev
terraform init   # first time only
terraform apply
```

Because the Ansible playbooks are idempotent, the first apply detects that the resources
already exist on FlashBlade and makes no changes — it only records them in Terraform state.
From this point on, Terraform manages them: any subsequent edits to `terraform.tfvars`
followed by `terraform apply` will update the real resources to match.

---

## Destroy

```bash
# Soft-delete buckets (recoverable from FlashBlade trash), then delete accounts
terraform destroy
```

To permanently eradicate a bucket on destroy, set `eradicate = true` for that bucket in
`terraform.tfvars` before running `terraform destroy`.

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
