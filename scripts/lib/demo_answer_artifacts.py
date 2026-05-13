#!/usr/bin/env python3
"""Resolve and validate demo answer OCI artifact metadata."""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


CREATE_MEDIA_TYPE = "application/vnd.greentic.answers.create.v1+json"
SETUP_MEDIA_TYPE = "application/vnd.greentic.answers.setup.v1+json"


@dataclass(frozen=True)
class AnswerArtifact:
    demo: str
    file: Path
    artifact: str
    media_type: str

    @property
    def kind(self) -> str:
        if self.artifact == "create" or self.artifact.startswith("create-"):
            return "create"
        if self.artifact == "setup" or self.artifact.startswith("setup-"):
            return "setup"
        raise ValueError(f"unsupported answer artifact name: {self.artifact}")

    def ref(self, owner: str, tag: str) -> str:
        return f"ghcr.io/{owner}/answers/{self.demo}/{self.artifact}:{tag}"


def _media_type_for_kind(kind: str) -> str:
    if kind == "create":
        return CREATE_MEDIA_TYPE
    if kind == "setup":
        return SETUP_MEDIA_TYPE
    raise ValueError(f"unsupported answer kind: {kind}")


def _kind_and_stem(path: Path) -> tuple[str, str]:
    name = path.name
    for kind in ("create", "setup"):
        suffix = f"-{kind}-answers.json"
        if name.endswith(suffix):
            return kind, name[: -len(suffix)]
    raise ValueError(f"not a create/setup answer file: {path}")


def infer_artifact(path: Path, known_demos: Iterable[str] = ()) -> AnswerArtifact:
    kind, stem = _kind_and_stem(path)
    known = sorted(set(known_demos), key=len, reverse=True)
    for demo in known:
        if stem == demo:
            return AnswerArtifact(demo, path, kind, _media_type_for_kind(kind))
        prefix = f"{demo}-"
        if stem.startswith(prefix):
            variant = stem[len(prefix) :]
            return AnswerArtifact(demo, path, f"{kind}-{variant}", _media_type_for_kind(kind))
    return AnswerArtifact(stem, path, kind, _media_type_for_kind(kind))


def validate_json_object(path: Path) -> None:
    try:
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as exc:
        raise ValueError(f"{path}: invalid JSON: {exc}") from exc
    except OSError as exc:
        raise ValueError(f"{path}: cannot read file: {exc}") from exc

    if not isinstance(data, dict):
        raise ValueError(f"{path}: top-level JSON value must be an object")


def _artifact_from_manifest_entry(entry: dict, manifest_path: Path) -> AnswerArtifact:
    try:
        demo = entry["demo"]
        file = Path(entry["file"])
        artifact = entry["artifact"]
        media_type = entry["media_type"]
    except KeyError as exc:
        raise ValueError(f"{manifest_path}: missing key {exc.args[0]!r}") from exc

    if not isinstance(demo, str) or not demo:
        raise ValueError(f"{manifest_path}: demo must be a non-empty string")
    if not isinstance(artifact, str) or not artifact:
        raise ValueError(f"{manifest_path}: artifact must be a non-empty string")
    if not isinstance(media_type, str) or not (
        media_type == "application/json" or media_type.endswith("+json")
    ):
        raise ValueError(f"{manifest_path}: media_type for {file} must be JSON-compatible")

    inferred_kind, _ = _kind_and_stem(file)
    if artifact == inferred_kind or artifact.startswith(f"{inferred_kind}-"):
        return AnswerArtifact(demo, file, artifact, media_type)
    raise ValueError(f"{manifest_path}: artifact {artifact!r} does not match {file.name}")


def load_manifest(demos_dir: Path) -> list[AnswerArtifact]:
    manifest_path = demos_dir / "demo-artifacts.json"
    try:
        with manifest_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError:
        return []
    except json.JSONDecodeError as exc:
        raise ValueError(f"{manifest_path}: invalid JSON: {exc}") from exc

    answers = data.get("answers")
    if not isinstance(answers, list):
        raise ValueError(f"{manifest_path}: answers must be an array")

    artifacts = [_artifact_from_manifest_entry(entry, manifest_path) for entry in answers]
    seen = set()
    for artifact in artifacts:
        key = (artifact.demo, artifact.artifact)
        if key in seen:
            raise ValueError(f"{manifest_path}: duplicate answer artifact {key[0]}/{key[1]}")
        seen.add(key)
    return artifacts


def list_artifacts(demos_dir: Path) -> list[AnswerArtifact]:
    manifest_artifacts = load_manifest(demos_dir)
    if manifest_artifacts:
        return manifest_artifacts

    files = sorted(demos_dir.glob("*-create-answers.json")) + sorted(
        demos_dir.glob("*-setup-answers.json")
    )
    return [infer_artifact(path) for path in sorted(files)]


def resolve_file(path: Path, demos_dir: Path) -> AnswerArtifact:
    manifest_artifacts = load_manifest(demos_dir)
    for artifact in manifest_artifacts:
        if artifact.file == path or artifact.file.resolve() == path.resolve():
            return artifact

    known_demos = [artifact.demo for artifact in manifest_artifacts]
    return infer_artifact(path, known_demos)


def _print_artifact(artifact: AnswerArtifact, owner: str | None, tag: str | None) -> None:
    fields = [
        str(artifact.file),
        artifact.demo,
        artifact.artifact,
        artifact.media_type,
    ]
    if owner and tag:
        fields.append(artifact.ref(owner, tag))
    print("\t".join(fields))


def cmd_list(args: argparse.Namespace) -> int:
    artifacts = list_artifacts(args.demos_dir)
    for artifact in artifacts:
        _print_artifact(artifact, args.owner, args.tag)
    return 0


def cmd_ref(args: argparse.Namespace) -> int:
    artifact = resolve_file(args.file, args.demos_dir)
    _print_artifact(artifact, args.owner, args.tag)
    return 0


def cmd_validate(args: argparse.Namespace) -> int:
    for file in args.files:
        validate_json_object(file)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="list answer artifacts")
    list_parser.add_argument("demos_dir", type=Path)
    list_parser.add_argument("--owner")
    list_parser.add_argument("--tag")
    list_parser.set_defaults(func=cmd_list)

    ref_parser = subparsers.add_parser("ref", help="resolve one answer artifact")
    ref_parser.add_argument("file", type=Path)
    ref_parser.add_argument("--demos-dir", type=Path, default=Path("demos"))
    ref_parser.add_argument("--owner")
    ref_parser.add_argument("--tag")
    ref_parser.set_defaults(func=cmd_ref)

    validate_parser = subparsers.add_parser("validate", help="validate answer JSON files")
    validate_parser.add_argument("files", nargs="+", type=Path)
    validate_parser.set_defaults(func=cmd_validate)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
