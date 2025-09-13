SHELL:=bash

test_suites = advanced

default: help

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: bootstrap
bootstrap: ## Bootstrap local environment for first use
	@make git-hooks

.PHONY: git-hooks
git-hooks: ## Set up hooks in .githooks
	@git submodule update --init .githooks ; \
	git config core.hooksPath .githooks \

.PHONY: test
test: ## Build, test, and destroy default scenario with Kitchen Terraform
	docker run --rm -e AWS_PROFILE=default -v $(shell pwd):/usr/action -v ~/.aws:/root/.aws -v /etc/ssl/certs/:/usr/local/share/ca-certificates/ quay.io/dwp/kitchen-terraform:0.14.7 "test $(test_suites) --destroy=always"

.PHONY: build
build: ## Build default scenario with Kitchen Terraform
	docker run --rm -e AWS_PROFILE=default -v $(shell pwd):/usr/action -v ~/.aws:/root/.aws -v /etc/ssl/certs/:/usr/local/share/ca-certificates/ quay.io/dwp/kitchen-terraform:0.14.7 "converge $(test_suites)"

.PHONY: verify
verify: ## Build default scenario with Kitchen Terraform
	docker run --rm -e AWS_PROFILE=default -v $(shell pwd):/usr/action -v ~/.aws:/root/.aws -v /etc/ssl/certs/:/usr/local/share/ca-certificates/ quay.io/dwp/kitchen-terraform:0.14.7 "verify $(test_suites)"

.PHONY: destroy
destroy: ## Build default scenario with Kitchen Terraform
	docker run --rm -e AWS_PROFILE=default -v $(shell pwd):/usr/action -v ~/.aws:/root/.aws -v /etc/ssl/certs/:/usr/local/share/ca-certificates/ quay.io/dwp/kitchen-terraform:0.14.7 "destroy $(test_suites)"
