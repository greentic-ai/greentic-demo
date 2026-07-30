#!/usr/bin/env python3
"""Demo bundles must vendor only the provider packs they actually configure.

A demo bundle is the reference for how someone else should compose one, so what
it ships is documentation. Before this gate, `quickstart-demo.gtbundle` was
11.2 MB of which 38 MB uncompressed (84% of the archive contents) was three
messaging channels whose every credential in the setup answers was `""` — Slack
alone was 22 MB. An unconfigured channel cannot connect to anything, so those
packs bought nothing and taught the wrong lesson.

The rule: vendor the browser tier, vendor what you configure, and add anything
else afterwards with `gtc provider add` (which stages a new revision with the
pack injected — no rebuild).
"""

from pathlib import Path
import json
import re


# `messaging-webchat-gui` ships the SPA *and* a webchat provider, so it is an
# alternative to `messaging-webchat`, never an addition: two webchat providers
# in one bundle both claim the same endpoints.
WEBCHAT_GUI = "messaging-webchat-gui"
WEBCHAT_PLAIN = "messaging-webchat"

# Neither webchat provider needs a credential — the browser tier is served from
# the pack and `jwt_signing_key` is generated when absent.
CREDENTIAL_EXEMPT = frozenset({WEBCHAT_GUI, WEBCHAT_PLAIN})

# Fields that make an outbound channel able to reach its platform. A channel
# with none of these set is inert no matter what else it carries: an
# `api_base_url` default does not make Slack reachable.
CREDENTIAL_KEY = re.compile(
    r"token|key|secret|password|app_id|sid|room|channel|team_id",
    re.IGNORECASE,
)


def provider_id(reference: str) -> str:
    """`oci://ghcr.io/greenticai/packs/state/state-memory:stable` -> `state-memory`."""
    return reference.rsplit("/", 1)[-1].split(":", 1)[0]


def bundle_answers(data: dict) -> dict:
    return (
        data.get("answers", {})
        .get("delegate_answer_document", {})
        .get("answers", {})
    )


def iter_demos():
    """Yield (create_path, create_answers, setup_answers_or_None) per demo."""
    for create in sorted(Path("demos").rglob("*-create-answers.json")):
        data = json.loads(create.read_text())
        setup_path = create.with_name(
            create.name.replace("-create-answers.json", "-setup-answers.json")
        )
        setup = json.loads(setup_path.read_text()) if setup_path.is_file() else None
        yield create, bundle_answers(data), setup


def test_extension_provider_entries_match_extension_providers():
    """The two views of the provider list must agree.

    `app_packs`/`app_pack_entries` already has this check in
    test_demo_json_remote_urls.py; providers drift the same way, and the bundle
    wizard reads both.
    """
    for create, answers, _ in iter_demos():
        providers = sorted(answers.get("extension_providers") or [])
        entries = sorted(
            entry["reference"]
            for entry in (answers.get("extension_provider_entries") or [])
            if isinstance(entry, dict) and "reference" in entry
        )
        assert providers == entries, (
            f"{create}: extension_providers and extension_provider_entries disagree\n"
            f"  extension_providers:        {providers}\n"
            f"  extension_provider_entries: {entries}"
        )


def test_no_bundle_vendors_two_webchat_providers():
    for create, answers, _ in iter_demos():
        ids = {provider_id(ref) for ref in (answers.get("extension_providers") or [])}
        assert not (WEBCHAT_GUI in ids and WEBCHAT_PLAIN in ids), (
            f"{create}: vendors both {WEBCHAT_GUI} and {WEBCHAT_PLAIN}. "
            f"{WEBCHAT_GUI} already ships a webchat provider, so both claim the "
            "same endpoints — keep exactly one."
        )


def test_no_bundle_vendors_the_state_memory_pack():
    """The environment binds the built-in `greentic.state.in-memory` State slot."""
    for create, answers, _ in iter_demos():
        ids = {provider_id(ref) for ref in (answers.get("extension_providers") or [])}
        assert "state-memory" not in ids, (
            f"{create}: vendors state-memory, but every environment already binds "
            "the built-in greentic.state.in-memory State slot."
        )


def test_no_bundle_vendors_a_deployer_pack():
    """`gtc install` hydrates the deployer dist packs where gtc's resolver looks.

    `resolve_canonical_target_provider_pack` reads
    `<greentic-deployer dir>/dist/<target>.gtpack`, and `gtc install` fills that
    directory for aws, azure and gcp. Vendoring one into a bundle pins a copy
    that goes stale and hides the missing `gtc install`.
    """
    for create, answers, _ in iter_demos():
        for ref in answers.get("extension_providers") or []:
            assert "/packs/deployer/" not in ref, (
                f"{create}: vendors the deployer pack {ref}. Run `gtc install` "
                "instead — it hydrates the aws/azure/gcp dist packs."
            )


def test_every_vendored_channel_has_a_credential():
    """A messaging channel with no credential configured cannot connect."""
    for create, answers, setup in iter_demos():
        if setup is None:
            continue
        setup_answers = setup.get("setup_answers") or {}
        for ref in answers.get("extension_providers") or []:
            pid = provider_id(ref)
            if not pid.startswith("messaging-") or pid in CREDENTIAL_EXEMPT:
                continue
            configured = {
                key: value
                for key, value in (setup_answers.get(pid) or {}).items()
                if CREDENTIAL_KEY.search(key) and value not in ("", None)
            }
            assert configured, (
                f"{create}: vendors {pid} but its setup answers configure no "
                f"credential, so the channel is inert. Drop the pack and let "
                f"users run `gtc provider add {pid}`."
            )


if __name__ == "__main__":
    test_extension_provider_entries_match_extension_providers()
    test_no_bundle_vendors_two_webchat_providers()
    test_no_bundle_vendors_the_state_memory_pack()
    test_no_bundle_vendors_a_deployer_pack()
    test_every_vendored_channel_has_a_credential()
    print("demo provider minimalism checks passed")
