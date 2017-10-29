####
# Terraform-Linode-NextCloud
####

GOLANG := $(shell go version 2> /dev/null)
TF := $(shell terraform version 2> /dev/null)

NEXTCLOUD_HOST ?= nextcloud.dev
COLLABORA_HOST ?= collabora.dev

AWS_ACCESS_KEY_ID ?= test
AWS_SECRET_ACCESS_KEY ?= test
AWS_DEFAULT_REGION ?= us-east-1

PROVIDER_REPO := github.com/mrvovanness/terraform-provider-linode
PROVIDER_PATH := $(GOPATH)/src/$(PROVIDER_REPO)

GOVENDOR_REPO := github.com/kardianos/govendor
GOVENDOR_PATH := $(GOPATH)/src/$(GOVENDOR_REPO)

# https://www.linode.com/docs/platform/api/api-key
LINODE_API_KEY :=
SSH_PUB_KEY_FILE := $(HOME)/.ssh/id_rsa.pub

.PHONY: golang tf init plan run run-local

docker-compose/certs:
	@mkdir -p $@

docker-compose/certs/default.crt: docker-compose/certs
	@openssl req \
	-x509 \
	-newkey rsa:4096 \
	-days 365 \
	-keyout docker-compose/certs/default.key \
	-nodes \
	-subj "/C=US/ST=Oregon/L=Portland/O=Localhost LLC/OU=Org/CN=$(NEXTCLOUD_HOST)" \
	-out $@

.PHONY: run-local
run-local: docker-compose/certs/default.crt
	@cd docker-compose \
	&& NEXTCLOUD_HOST=$(NEXTCLOUD_HOST) \
	COLLABORA_HOST=$(COLLABORA_HOST) \
	COLLABORA_USER=admin \
	COLLABORA_PASSWORD=password \
	CERT_NAME=default \
	docker-compose up --build -d

.PHONY: run
run:
	@cd docker-compose \
	&& NEXTCLOUD_HOST=$(NEXTCLOUD_HOST) \
	COLLABORA_HOST=$(COLLABORA_HOST) \
	COLLABORA_USER=admin \
	COLLABORA_PASSWORD=password \
	docker-compose up --build -d

.PHONY: stop
stop:
	@cd docker-compose && docker-compose stop ; docker-compose rm -fv

tf:
ifndef TF
	@$(error "It appears you don't have terraform installed, please install it!")
endif

golang:
ifndef GOLANG
	@$(error "It appears you don't have golang installed, please install from: https://golang.org/dl/")
endif

$(PROVIDER_PATH): golang
	@go get -u $(PROVIDER_REPO)

$(GOVENDOR_PATH): golang
	@go get -u $(GOVENDOR_REPO)

$(HOME)/.terraform.d/plugins/terraform-provider-linode: $(GOVENDOR_PATH) $(PROVIDER_PATH)
	echo "home=$(HOME)"
	cd $(PROVIDER_PATH) && govendor sync
	go build -o $@ \
	$(PROVIDER_PATH)/main.go \
	$(PROVIDER_PATH)/provider.go \
	$(PROVIDER_PATH)/resource_linode.go

init: $(HOME)/.terraform.d/plugins/terraform-provider-linode tf
	@TF_VAR_linode_api_key=$(LINODE_API_KEY) \
	terraform init .

plan: init
	@TF_VAR_linode_api_key=$(LINODE_API_KEY) \
	TF_VAR_ssh_key_file=$(SSH_PUB_KEY_FILE) \
	terraform plan .
