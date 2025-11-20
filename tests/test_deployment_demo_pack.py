"""Lightweight checks for the deployment demo pack."""

from pathlib import Path
import json
import unittest


ROOT = Path(__file__).resolve().parents[1]
DEPLOY_PACK = ROOT / "examples" / "deployment" / "generic-deploy.gtpack"


class DeploymentDemoPackTests(unittest.TestCase):
    def test_manifest_declares_deployment_kind(self) -> None:
        manifest = DEPLOY_PACK / "manifest.yaml"
        self.assertTrue(manifest.exists(), "manifest.yaml missing")
        text = manifest.read_text()
        self.assertIn("kind: deployment", text)
        self.assertIn("deploy_generic_iac", text)

    def test_index_references_deployment_pack(self) -> None:
        index_path = ROOT / "examples" / "index.json"
        index = json.loads(index_path.read_text())
        self.assertIn("deployment-demo", index)
        locator = index["deployment-demo"]["main_pack"]["locator"]
        self.assertIn("generic-deploy.gtpack/manifest.yaml", locator)

    def test_stub_component_instructions_present(self) -> None:
        stub_readme = ROOT / "examples" / "deployment" / "stub-deploy-component" / "README.md"
        self.assertTrue(stub_readme.exists(), "stub README missing")
        self.assertIn("wasm32-wasi", stub_readme.read_text())

    def test_component_manifest_advertises_iac(self) -> None:
        manifest = DEPLOY_PACK / "components" / "greentic.deploy.generic.iac.yaml"
        self.assertTrue(manifest.exists(), "component manifest missing")
        text = manifest.read_text()
        self.assertIn("iac:", text)
        self.assertIn("write_templates: true", text)


if __name__ == "__main__":
    unittest.main()
