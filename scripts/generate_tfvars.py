#!/usr/bin/env python3
"""Query FlashBlade and generate terraform.tfvars for importing existing resources.

Usage:
    # Query FlashBlade and print tfvars to stdout (all accounts and buckets):
    python3 scripts/generate_tfvars.py --fb-url 10.225.112.185 --api-token T-xxx

    # Filter to specific accounts:
    python3 scripts/generate_tfvars.py --fb-url 10.225.112.185 --api-token T-xxx \
        --account myteam --account otherteam

    # Write directly to tfvars file:
    python3 scripts/generate_tfvars.py --fb-url 10.225.112.185 --api-token T-xxx \
        -o envs/dev/terraform.tfvars

    # Or use environment variables:
    export PUREFB_URL=10.225.112.185
    export PUREFB_API=T-xxx
    python3 scripts/generate_tfvars.py -o envs/dev/terraform.tfvars

    # From a previously saved JSON file (from fb_import.yml playbook):
    python3 scripts/generate_tfvars.py --from-json fb_state.json
"""

import argparse
import os
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


def fetch_from_flashblade(fb_url, api_token):
    """Query FlashBlade API and return accounts and buckets dicts."""
    try:
        from pypureclient import flashblade
    except ImportError:
        print(
            "Error: pypureclient is not installed. "
            "Activate the ansible_env virtualenv first:\n"
            "  source ansible_env/bin/activate",
            file=sys.stderr,
        )
        sys.exit(1)

    client = flashblade.Client(target=fb_url, api_token=api_token)

    # Fetch accounts
    accounts = {}
    res = client.get_object_store_accounts()
    if res.status_code != 200:
        print(f"Error fetching accounts: {res.errors[0].message}", file=sys.stderr)
        sys.exit(1)
    for acct in res.items:
        accounts[acct.name] = {
            "quota_limit": acct.quota_limit,
            "hard_limit_enabled": getattr(acct, "hard_limit_enabled", False),
        }

    # Fetch buckets
    buckets = {}
    res = client.get_buckets()
    if res.status_code != 200:
        print(f"Error fetching buckets: {res.errors[0].message}", file=sys.stderr)
        sys.exit(1)
    for bkt in res.items:
        buckets[bkt.name] = {
            "account_name": bkt.account.name,
            "versioning": bkt.versioning,
            "quota_limit": bkt.quota_limit,
            "destroyed": bkt.destroyed,
        }

    return {"accounts": accounts, "buckets": buckets}


def load_from_json(path):
    """Load previously saved JSON from fb_import.yml playbook."""
    with open(path) as f:
        return json.load(f)


def generate_tfvars(data, account_filters=None):
    """Generate terraform.tfvars content from FlashBlade data."""
    accounts = data.get("accounts", {})
    buckets = data.get("buckets", {})

    # Filter accounts if requested
    if account_filters:
        missing = [a for a in account_filters if a not in accounts]
        if missing:
            print(f"Error: account(s) not found: {', '.join(missing)}", file=sys.stderr)
            print(
                f"Available accounts: {', '.join(sorted(accounts.keys()))}",
                file=sys.stderr,
            )
            sys.exit(1)
        accounts = {k: v for k, v in accounts.items() if k in account_filters}

    if len(accounts) == 0:
        print("Error: no accounts found on FlashBlade.", file=sys.stderr)
        sys.exit(1)

    lines = []

    # S3 accounts
    lines.append("s3_accounts = {")
    for acct_name in sorted(accounts):
        acct_data = accounts[acct_name]
        quota_limit = acct_data.get("quota_limit")
        hard_limit = acct_data.get("hard_limit_enabled", False)

        quota_str = humanize_bytes(quota_limit) if quota_limit else ""

        lines.append(f'  "{acct_name}" = {{')
        if quota_str:
            lines.append(f'    quota      = "{quota_str}"')
        if hard_limit:
            lines.append(f"    hard_limit = true")
        lines.append("  }")
    lines.append("}")

    # Buckets (only those belonging to selected accounts, skip destroyed)
    account_names = set(accounts.keys())
    active_buckets = {
        name: bdata
        for name, bdata in buckets.items()
        if bdata.get("account_name") in account_names and not bdata.get("destroyed", False)
    }

    lines.append("")
    lines.append("buckets = {")
    for bname in sorted(active_buckets):
        bdata = active_buckets[bname]
        lines.append(f'  "{bname}" = {{')
        lines.append(f'    account_name = "{bdata["account_name"]}"')

        versioning = bdata.get("versioning", "")
        if versioning in ("enabled", "suspended"):
            lines.append(f'    versioning   = "{versioning}"')

        bucket_quota = bdata.get("quota_limit")
        if bucket_quota:
            lines.append(f'    quota        = "{humanize_bytes(bucket_quota)}"')

        lines.append("  }")
    lines.append("}")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Query FlashBlade and generate terraform.tfvars for importing existing resources."
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument(
        "--from-json",
        metavar="FILE",
        help="Load from a previously saved JSON file instead of querying FlashBlade",
    )
    parser.add_argument("--fb-url", help="FlashBlade management IP/hostname (or set PUREFB_URL)")
    parser.add_argument("--api-token", help="FlashBlade API token (or set PUREFB_API)")
    parser.add_argument(
        "--account",
        action="append",
        dest="accounts",
        help="Filter to specific account(s). Can be repeated. Omit for all accounts.",
    )
    parser.add_argument("-o", "--output", help="Output file (default: stdout)")
    args = parser.parse_args()

    if args.from_json:
        data = load_from_json(args.from_json)
    else:
        fb_url = args.fb_url or os.environ.get("PUREFB_URL")
        api_token = args.api_token or os.environ.get("PUREFB_API")
        if not fb_url or not api_token:
            print(
                "Error: provide --fb-url and --api-token, or set PUREFB_URL and PUREFB_API env vars.",
                file=sys.stderr,
            )
            sys.exit(1)
        data = fetch_from_flashblade(fb_url, api_token)

    tfvars = generate_tfvars(data, args.accounts)

    if args.output:
        with open(args.output, "w") as f:
            f.write(tfvars + "\n")
        print(f"Written to {args.output}", file=sys.stderr)
    else:
        print(tfvars)


if __name__ == "__main__":
    main()
