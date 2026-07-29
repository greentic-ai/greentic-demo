#!/usr/bin/env python3

from pathlib import Path
import json
import re


FORBIDDEN_PATTERNS = [
    re.compile(r"file://"),
    re.compile(r"(?:^|\s)\./"),
    re.compile(r"(?:^|\s)\.\./"),
    re.compile(r"(?:^|\s)demos/[^\" ]+"),
    re.compile(r"(?:^|\s)(?:\./|\.\./)?[^:/?#\s]+\.gtpack(?:$|[?#\s])"),
    re.compile(r"github\.com/greenticai/greentic-demo/releases/download/"),
]


def walk(value, path="root"):
    if isinstance(value, dict):
        for key, child in value.items():
            walk(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            walk(child, f"{path}[{index}]")
    elif isinstance(value, str):
        for pattern in FORBIDDEN_PATTERNS:
            assert not pattern.search(value), (
                f"Local file reference found at {path}: {value}"
            )


def test_demo_json_uses_remote_urls():
    # Only check wizard answer files (*-create-answers.json, *-setup-answers.json).
    # Other JSON files in demos/ (demo-artifacts.json, *-secret-questions.json,
    # *.local.json) use different schemas and intentionally contain local paths.
    for file in Path("demos").rglob("*-answers.json"):
        data = json.loads(file.read_text())
        walk(data, str(file))


# The blocklist above is leaky by construction: it only rejects shapes someone
# thought to enumerate. `packs/redbutton-demo.pack` (a `.pack` directory) and
# `public-deployer-aws-vm` (a bare name, no extension) both sailed through it
# and shipped bundles with no application inside. Pack references get an
# allowlist instead — a reference is either a release download or an OCI ref,
# and anything else is rejected whether or not we predicted its shape.
ALLOWED_PACK_REF = re.compile(
    r"^(?:"
    r"https://github\.com/greenticai/greentic-demo/releases/latest/download/[^/]+\.gtpack"
    r"|oci://[^\s]+"
    r")$"
)


def iter_pack_refs(data):
    """Yield (json_path, reference) for every pack reference in an answers doc."""
    answers = (
        data.get("answers", {})
        .get("delegate_answer_document", {})
        .get("answers", {})
    )
    for field in ("app_packs", "extension_providers"):
        for index, ref in enumerate(answers.get(field) or []):
            yield f"{field}[{index}]", ref
    for field in ("app_pack_entries", "extension_provider_entries"):
        for index, entry in enumerate(answers.get(field) or []):
            if isinstance(entry, dict) and "reference" in entry:
                yield f"{field}[{index}].reference", entry["reference"]


def test_pack_references_are_resolvable_shapes():
    for file in Path("demos").rglob("*-create-answers.json"):
        data = json.loads(file.read_text())
        for path, ref in iter_pack_refs(data):
            assert ALLOWED_PACK_REF.match(ref), (
                f"{file}: {path} is not a published artifact reference: {ref!r}\n"
                f"  expected a releases/latest/download/*.gtpack URL or an oci:// ref"
            )


def test_app_pack_entries_match_app_packs():
    """`app_packs` and `app_pack_entries[].reference` must list the same packs.

    They are two views of one list and the bundle wizard reads both; letting
    them drift means the bundle silently builds from a different set than the
    one the entries describe.
    """
    for file in Path("demos").rglob("*-create-answers.json"):
        data = json.loads(file.read_text())
        answers = (
            data.get("answers", {})
            .get("delegate_answer_document", {})
            .get("answers", {})
        )
        packs = sorted(answers.get("app_packs") or [])
        entries = sorted(
            entry["reference"]
            for entry in (answers.get("app_pack_entries") or [])
            if isinstance(entry, dict) and "reference" in entry
        )
        assert packs == entries, (
            f"{file}: app_packs and app_pack_entries disagree\n"
            f"  app_packs:         {packs}\n"
            f"  app_pack_entries:  {entries}"
        )


if __name__ == "__main__":
    test_demo_json_uses_remote_urls()
    test_pack_references_are_resolvable_shapes()
    test_app_pack_entries_match_app_packs()
    print("demo answer URL checks passed")
