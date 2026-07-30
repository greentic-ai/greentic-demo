#!/usr/bin/env python3

"""Every bundle create-answers document must actually build a bundle.

`locks.execution` selects whether the bundle wizard performs the composition or
only plans it. With `"dry_run"` the wizard emits no `dist/<bundle_id>.gtbundle`,
so `package_demos.sh` falls back to `greentic-setup bundle build` over the raw
wizard workspace and squashes *that* — logs, state, `.providers/` config
envelopes and all. The result carries no `bundle-manifest.json`, which makes
`op env apply` (and therefore `gtc start <oci-ref> --target gcp`) reject it with
"extracted tree has no bundle-manifest.json", while every step of packaging and
publishing still exits 0.

cloud-deploy-demo shipped that way from 2026-04-26 until this check landed.
`package_demos.sh` now also verifies the built artifact's shape, but that gate
needs the full toolchain and a packaging run; this one is a plain JSON invariant,
so it runs on every PR and names the root cause directly.
"""

import json
import sys
from pathlib import Path

REQUIRED_EXECUTION = "execute"


def test_create_answers_execute_the_build():
    checked = 0
    failures = []

    for file in sorted(Path("demos").rglob("*-create-answers.json")):
        data = json.loads(file.read_text())
        locks = data.get("answers", {}).get("delegate_answer_document", {}).get("locks", {})
        execution = locks.get("execution")
        checked += 1
        if execution != REQUIRED_EXECUTION:
            failures.append(f"  {file}: locks.execution is {execution!r}, expected {REQUIRED_EXECUTION!r}")

    assert checked > 0, "no demos/*-create-answers.json documents found"
    assert not failures, (
        "bundle create-answers documents that do not build a bundle:\n"
        + "\n".join(failures)
        + "\n\nA dry_run produces a wizard workspace instead of a bundle; "
        "op env apply rejects it for having no bundle-manifest.json."
    )
    return checked


if __name__ == "__main__":
    count = test_create_answers_execute_the_build()
    print(f"demo bundle build-mode checks passed ({count} create-answers documents)")
    sys.exit(0)
