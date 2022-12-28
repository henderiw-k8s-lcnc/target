# ====================================================================================
# Setup Project

VERSION ?= latest
REGISTRY ?= yndd
PROJECT ?= target

KPT_BLUEPRINT_CFG_DIR ?= blueprint/fn-config
KPT_BLUEPRINT_PKG_DIR ?= blueprint/${PROJECT}


# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Private Github REPOs
GITHUB_TOKEN ?= $(shell cat ~/.config/github.token)

.PHONY: all
all: build

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development
.PHONY: generate
generate: controller-gen kpt kptgen ## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
	mkdir -p ${KPT_BLUEPRINT_CFG_DIR}
	mkdir -p ${KPT_BLUEPRINT_PKG_DIR}/crd/bases
	$(CONTROLLER_GEN) crd paths="./..." output:crd:artifacts:config=${KPT_BLUEPRINT_PKG_DIR}/crd/bases
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."
	kpt pkg init ${KPT_BLUEPRINT_PKG_DIR} --description "${PROJECT} controller"
	kpt pkg init ${KPT_BLUEPRINT_PKG_DIR}/crd --description "${PROJECT} crd"
	kptgen apply config ${KPT_BLUEPRINT_PKG_DIR} --fn-config-dir ${KPT_BLUEPRINT_CFG_DIR}
	rm ${KPT_BLUEPRINT_PKG_DIR}/package-context.yaml
	rm ${KPT_BLUEPRINT_PKG_DIR}/crd/package-context.yaml

.PHONY: fmt
fmt: ## Run go fmt against code.
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

##@ Build Dependencies

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
KUSTOMIZE ?= $(LOCALBIN)/kustomize
CONTROLLER_GEN ?= $(LOCALBIN)/controller-gen
ENVTEST ?= $(LOCALBIN)/setup-envtest
KPT ?= $(LOCALBIN)/kpt
KPTGEN ?= $(LOCALBIN)/kptgen

## Tool Versions
KUSTOMIZE_VERSION ?= v3.8.7
CONTROLLER_TOOLS_VERSION ?= v0.9.2
ENVTEST_K8S_VERSION ?= 1.24.2
KPT_VERSION ?= main
KPTGEN_VERSION ?= v0.0.9

KUSTOMIZE_INSTALL_SCRIPT ?= "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"
.PHONY: kustomize
kustomize: $(KUSTOMIZE) ## Download kustomize locally if necessary.
$(KUSTOMIZE): $(LOCALBIN)
	test -s $(LOCALBIN)/kustomize || { curl -s $(KUSTOMIZE_INSTALL_SCRIPT) | bash -s -- $(subst v,,$(KUSTOMIZE_VERSION)) $(LOCALBIN); }

.PHONY: controller-gen
controller-gen: $(CONTROLLER_GEN) ## Download controller-gen locally if necessary.
$(CONTROLLER_GEN): $(LOCALBIN)
	test -s $(LOCALBIN)/controller-gen || GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-tools/cmd/controller-gen@$(CONTROLLER_TOOLS_VERSION)

.PHONY: envtest
envtest: $(ENVTEST) ## Download envtest-setup locally if necessary.
$(ENVTEST): $(LOCALBIN)
	test -s $(LOCALBIN)/setup-envtest || GOBIN=$(LOCALBIN) go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest

.PHONY: kpt
kpt: $(KPT) ## Download kpt locally if necessary.
$(KPT): $(LOCALBIN)
	test -s $(LOCALBIN)/kpt || GOBIN=$(LOCALBIN) go install -v github.com/GoogleContainerTools/kpt@$(KPT_VERSION)

.PHONY: kptgen
kptgen: $(KPTGEN) ## Download kptgen locally if necessary.
$(KPTGEN): $(LOCALBIN)
	test -s $(LOCALBIN)/kptgen || GOBIN=$(LOCALBIN) go install -v github.com/henderiw-kpt/kptgen@$(KPTGEN_VERSION)