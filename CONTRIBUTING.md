# Contributing

This repository contains the WProofreader Admin-panel Helm chart.
Application source changes belong in the Admin-panel application repository.

## Report an issue

Search the [open issues](https://github.com/WebSpellChecker/admin-panel-helm/issues)
before you open a new one.
Include the chart version, Kubernetes version, relevant values with secrets removed,
the command that failed, and the complete error message.

Use the [security policy](SECURITY.md) for a suspected vulnerability.
Do not put credentials, license data, or customer data in an issue.

## Prepare a change

You need Helm 3, kubeconform, helm-docs 1.14.2, and pre-commit.
Run all commands from the repository root.

1. Create a branch from `development`.
2. Make one focused change.
   Use two-space YAML indentation and kebab-case filenames.
3. Add a `# --` description for each public value.
   Update `values.yaml`, `values.schema.json`, `docs/ENVIRONMENT_VARIABLES.md`,
   and the relevant templates together.
4. Run `make docs` after you change chart metadata, defaults, or value descriptions.
5. Run the checks:

   ```bash
   make check
   pre-commit run --all-files
   ```

6. Test invalid combinations that the chart must reject.
   Test both the enabled and disabled forms of the feature you changed.
7. Use a Conventional Commit subject such as `feat:`, `fix:`, `docs:`, or `refactor:`.

`admin-panel/README.md` is generated from `admin-panel/README.md.gotmpl`.
Do not edit the generated file directly.

## Version and release metadata

Bump `admin-panel/Chart.yaml` for a change to the packaged chart.
Use Semantic Versioning.
Update `CHANGELOG.md` and the `artifacthub.io/changes` annotation in the same pull request.
A documentation-only change outside `admin-panel/` does not need a chart version bump.

The release workflow publishes each new chart version after it reaches `master`.
It creates a `v<version>` GitHub Release and updates the Helm repository index on
the `gh-pages` branch.
The repository administrator must create that branch and configure GitHub Pages
before the first release.

After the first publication, register the repository URL
with [Artifact Hub](https://artifacthub.io/docs/topics/repositories/helm-charts/).
If you claim ownership or request verified-publisher status,
put `artifacthub-repo.yml` next to `index.yaml` on `gh-pages`,
using the repository ID that Artifact Hub provides.

## Pull requests

Explain the operator impact and link the issue.
Include the validation commands you ran.
For a manifest change, include the relevant rendered output.
Keep generated files, examples, and user documentation in the same pull request as
the behavior they describe.
