SHELL := /usr/bin/env bash

CHART_DIR := admin-panel
PACKAGE_DIR ?= dist

.PHONY: check docs docs-check package secrets validate

check: validate docs-check

validate:
	./scripts/validate-chart.sh

docs:
	helm-docs --chart-search-root=$(CHART_DIR) --template-files=README.md.gotmpl

docs-check:
	./scripts/check-generated-docs.sh

secrets:
	pre-commit run --all-files

package: check
	mkdir -p $(PACKAGE_DIR)
	helm package $(CHART_DIR) --destination $(PACKAGE_DIR)
