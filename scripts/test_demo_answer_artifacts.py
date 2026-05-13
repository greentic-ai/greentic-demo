#!/usr/bin/env python3

import json
import tempfile
import unittest
from pathlib import Path

from lib.demo_answer_artifacts import (
    CREATE_MEDIA_TYPE,
    SETUP_MEDIA_TYPE,
    infer_artifact,
    list_artifacts,
    validate_json_object,
)


class DemoAnswerArtifactsTest(unittest.TestCase):
    def test_basic_create_mapping(self):
        artifact = infer_artifact(Path("demos/foo-create-answers.json"))
        self.assertEqual(artifact.demo, "foo")
        self.assertEqual(artifact.artifact, "create")
        self.assertEqual(artifact.media_type, CREATE_MEDIA_TYPE)

    def test_basic_setup_mapping(self):
        artifact = infer_artifact(Path("demos/foo-setup-answers.json"))
        self.assertEqual(artifact.demo, "foo")
        self.assertEqual(artifact.artifact, "setup")
        self.assertEqual(artifact.media_type, SETUP_MEDIA_TYPE)

    def test_deep_research_standard_mapping(self):
        demos = ["deep-research-demo"]
        create = infer_artifact(Path("demos/deep-research-demo-create-answers.json"), demos)
        setup = infer_artifact(Path("demos/deep-research-demo-setup-answers.json"), demos)
        self.assertEqual((create.demo, create.artifact), ("deep-research-demo", "create"))
        self.assertEqual((setup.demo, setup.artifact), ("deep-research-demo", "setup"))

    def test_deep_research_aws_mapping(self):
        demos = ["deep-research-demo"]
        create = infer_artifact(Path("demos/deep-research-demo-aws-create-answers.json"), demos)
        setup = infer_artifact(Path("demos/deep-research-demo-aws-setup-answers.json"), demos)
        self.assertEqual((create.demo, create.artifact), ("deep-research-demo", "create-aws"))
        self.assertEqual((setup.demo, setup.artifact), ("deep-research-demo", "setup-aws"))

    def test_generated_ref(self):
        artifact = infer_artifact(Path("demos/foo-create-answers.json"))
        self.assertEqual(
            artifact.ref("greenticai", "dev"),
            "ghcr.io/greenticai/answers/foo/create:dev",
        )

    def test_validate_rejects_invalid_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "bad-create-answers.json"
            path.write_text("{", encoding="utf-8")
            with self.assertRaises(ValueError):
                validate_json_object(path)

    def test_validate_rejects_top_level_array(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "array-create-answers.json"
            path.write_text("[]", encoding="utf-8")
            with self.assertRaises(ValueError):
                validate_json_object(path)

    def test_manifest_mapping(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            demos = root / "demos"
            demos.mkdir()
            answer = demos / "deep-research-demo-aws-create-answers.json"
            answer.write_text("{}", encoding="utf-8")
            (demos / "demo-artifacts.json").write_text(
                json.dumps(
                    {
                        "answers": [
                            {
                                "demo": "deep-research-demo",
                                "file": str(answer),
                                "artifact": "create-aws",
                                "media_type": CREATE_MEDIA_TYPE,
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )

            artifacts = list_artifacts(demos)
            self.assertEqual(len(artifacts), 1)
            self.assertEqual(artifacts[0].demo, "deep-research-demo")
            self.assertEqual(artifacts[0].artifact, "create-aws")

    def test_committed_manifest_files_are_json_objects(self):
        repo_root = Path(__file__).resolve().parents[1]
        artifacts = list_artifacts(repo_root / "demos")
        self.assertGreater(len(artifacts), 0)
        for artifact in artifacts:
            validate_json_object(repo_root / artifact.file)


if __name__ == "__main__":
    unittest.main()
