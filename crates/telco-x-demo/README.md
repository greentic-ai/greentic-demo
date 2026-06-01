# Telco-X Demo

Telco-X messaging demo for Webchat GUI with category menus and telco playbook flows.

## Package

```bash
bash scripts/package_demos.sh telco-x-demo
```

## Run

```bash
gtc wizard --answers demos/telco-x-demo-create-answers.json
gtc setup --answers demos/telco-x-demo-setup-answers.json ./telco-x-demo-bundle
gtc start ./telco-x-demo-bundle
```

## Webchat

Open the URL printed by `gtc start`.

For the default local run, it looks like:

```text
http://127.0.0.1:8080/v1/web/webchat/demo/
```

Try:

- `show overutilised aci ports`
- `show recent change correlation`
- `run vm rca`
- `investigate service degradation`

## External Operator Profile

The demo bundle ships with embedded Telco-X data so it works out of the box. For operator-specific demonstrations, keep the generic Telco-X code unchanged and supply an external operator profile to the presentation component:

- `operator_profile.resolver_catalog_json`: serialized Telco-X resolver catalog JSON
- `operator_profile.adapter_fixtures_json`: serialized Telco-X adapter fixture/source JSON

The reference demo operator profile is published here:

```text
https://github.com/greentic-biz/demo-operator-telco/releases/latest/download/resolver_catalog.json
https://github.com/greentic-biz/demo-operator-telco/releases/latest/download/adapter_fixtures.json
https://github.com/greentic-biz/demo-operator-telco/releases/latest/download/playbook_config.json
https://github.com/greentic-biz/demo-operator-telco/releases/latest/download/component_registry.yaml
```

Because that repository is private, those links require GitHub access. For a public hand-off, publish the same files to a public release or OCI artifact and point the bundle setup at that location.
