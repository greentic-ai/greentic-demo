#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/publish_demo_artifacts_oci.sh" "$@"
