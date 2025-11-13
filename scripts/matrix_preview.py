"""Helper CLI to preview the matrix combinations used by the deploy workflow."""

from __future__ import annotations

import argparse

from scripts.matrix_helpers import combinations, selected_list


def main() -> None:
    parser = argparse.ArgumentParser(description="Preview matrix selections.")
    parser.add_argument(
        "--providers",
        default="",
        help="Comma-separated providers (aws,gcp,azure). Leave empty for defaults.",
    )
    parser.add_argument(
        "--environments",
        default="",
        help="Comma-separated environments (dev,prod). Leave empty for defaults.",
    )
    args = parser.parse_args()

    active_providers = selected_list(args.providers, "aws,gcp,azure")
    active_environments = selected_list(args.environments, "dev,prod")

    print("Selected providers:", active_providers)
    print("Selected environments:", active_environments)
    print("Matrix combinations:")
    for provider, environment in combinations(active_providers, active_environments):
        print(f"- {provider} / {environment}")


if __name__ == "__main__":
    main()
