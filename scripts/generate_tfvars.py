#!/usr/bin/env python3
"""Generate terraform.tfvars from FlashBlade state gathered by fb_import.yml.

Usage:
    # Run the import playbook first, saving JSON to a file:
    ansible-playbook ansible-fb/playbooks/fb_import.yml \
        -e fb_url=10.225.112.185 -e api_token=T-xxx \
        -e output_file=fb_state.json

    # Then generate tfvars (all accounts):
    python3 scripts/generate_tfvars.py fb_state.json

    # Or filter to a single account:
    python3 scripts/generate_tfvars.py fb_state.json --account myaccount

    # Write directly to tfvars file:
    python3 scripts/generate_tfvars.py fb_state.json --account myaccount -o envs/dev/terraform.tfvars
"""

import argparse
import json
import sys


def humanize_bytes(n):
    """Convert bytes to human-readable string (e.g. 107374182400 -> '100G')."""
    if n is None or n == 0:
        return ""
    for unit in ["", "K", "M", "G", "T", "P"]:
        if abs(n) < 1024:
            if n == int(n):
                return f"{int(n)}{unit}" if unit else ""
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}E"


def generate_tfvars(data, account_filter=None):
    """Generate terraform.tfvars content from FlashBlade import data."""
    accounts = data.get("accounts", {})
    buckets = data.get("buckets", {})

    # Use explicit filter, then fall back to playbook-level filter
    if not account_filter:
        account_filter = data.get("account_filter", "")

    # Filter accounts
    if account_filter:
        accounts = {k: v for k, v in accounts.items() if k == account_filter}
        if not accounts:
            print(f"Error: account '{account_filter}' not found.", file=sys.stderr)
            print(f"Available accounts: {', '.join(data.get('accounts', {}).keys())}", file=sys.stderr)
            sys.exit(1)

    if len(accounts) == 0:
        print("Error: no accounts found on FlashBlade.", file=sys.stderr)
        sys.exit(1)

    if len(accounts) > 1 and not account_filter:
        print("Multiple accounts found. Use --account to select one:", file=sys.stderr)
        for name in accounts:
            print(f"  {name}", file=sys.stderr)
        sys.exit(1)

    account_name = list(accounts.keys())[0]
    account_data = accounts[account_name]

    lines = []
    lines.append(f's3_account_name = "{account_name}"')

    # Account quota
    quota_limit = account_data.get("quota_limit")
    if quota_limit:
        quota_str = humanize_bytes(quota_limit)
        if quota_str:
            lines.append(f's3_account_quota      = "{quota_str}"')

    hard_limit = account_data.get("hard_limit_enabled", False)
    if hard_limit:
        lines.append(f"s3_account_hard_limit = true")

    # Buckets belonging to this account
    account_buckets = {}
    for bucket_name, bucket_data in buckets.items():
        if bucket_data.get("account_name") != account_name:
            continue
        if bucket_data.get("destroyed", False):
            continue

        config = {}

        versioning = bucket_data.get("versioning", "")
        if versioning in ("enabled", "suspended"):
            config["versioning"] = versioning

        bucket_quota = bucket_data.get("quota_limit")
        if bucket_quota:
            config["quota"] = humanize_bytes(bucket_quota)

        account_buckets[bucket_name] = config

    lines.append("")
    lines.append("buckets = {")
    for bname, bconfig in sorted(account_buckets.items()):
        lines.append(f'  "{bname}" = {{')
        if "versioning" in bconfig:
            lines.append(f'    versioning = "{bconfig["versioning"]}"')
        if "quota" in bconfig:
            lines.append(f'    quota      = "{bconfig["quota"]}"')
        lines.append("  }")
    lines.append("}")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Generate terraform.tfvars from FlashBlade import JSON."
    )
    parser.add_argument("input", help="Path to JSON file from fb_import.yml")
    parser.add_argument("--account", help="Filter to a specific S3 account name")
    parser.add_argument("-o", "--output", help="Output file (default: stdout)")
    args = parser.parse_args()

    with open(args.input) as f:
        data = json.load(f)

    tfvars = generate_tfvars(data, args.account)

    if args.output:
        with open(args.output, "w") as f:
            f.write(tfvars + "\n")
        print(f"Written to {args.output}", file=sys.stderr)
    else:
        print(tfvars)


if __name__ == "__main__":
    main()
