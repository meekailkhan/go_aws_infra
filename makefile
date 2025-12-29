MIGRATION_DIR := migration
AWS_ACCOUNT_ID := 577905065178
AWS_DEFAULT_REGION := us-west-2
AWS_ECR_DOMAIN := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com
GIT_SHA := $(shell git rev-parse HEAD)
BUILD_IMAGE := $(AWS_ECR_DOMAIN)/meekail-cloud-infra
BUILD_TAG ?= latest
DOCKERIZE_HOST := $(shell echo $(GOOSE_DBSTRING) | cut -d "@" -f 2 | cut -d ":" -f 1)
DOCKERIZE_URL := $(if $(DOCKERIZE_HOST)$(DOCKERIZE_HOST):5432,localhost:5432)
.DEFAULT_GOAL := build 

build:
	go build -o ./goals main.go

build-image:
	sudo docker buildx build \
	--platform "linux/amd64" \
	--tag "$(BUILD_IMAGE):$(GIT_SHA)-build" \
	--target "build" \
	.
	sudo docker buildx build \
		--cache-from "$(BUILD_IMAGE):$(GIT_SHA)-build" \
		--platform "linux/amd64" \
		--tag "$(BUILD_IMAGE):$(GIT_SHA)" \
		.

build-image-login:
	aws ecr get-login-password --region us-west-2 | docker login \
	--username AWS \
	--password-stdin \
	"$(AWS_ECR_DOMAIN)"

build-image-push: build-image-login
	sudo docker image push $(BUILD_IMAGE):$(GIT_SHA)

build-image-pull: build-image-login
	sudo docker image pull $(BUILD_IMAGE):$(GIT_SHA)

build-image-migrate:
	sudo docker container run \
		--entrypoint "dockerize" \
		--network "host" \
		--rm \
		$(BUILD_IMAGE):$(GIT_SHA) \
		-timeout 30s \
		-wait \
		$(DOCKERIZE_URL)
	sudo docker container run \
		--entrypoint "goose" \
		--env "GOOSE_DBSTRING" \
		--env "GOOSE_DRIVER" \
		--network "host" \
		--rm \
		$(BUILD_IMAGE):$(GIT_SHA) \
		-dir $(MIGRATION_DIR) status
	sduo docker container run \
		--entrypoint "goose" \
		--env "GOOSE_DBSTRING" \
		--env "GOOSE_DRIVER" \
		--network "host" \
		--rm \
		$(BUILD_IMAGE):$(GIT_SHA) \
		-dir $(MIGRATION_DIR) validate
	sudo docker container run \
		--entrypoint "goose" \
		--env "GOOSE_DBSTRING" \
		--env "GOOSE_DRIVER" \
		--network "host" \
		--rm \
		$(BUILD_IMAGE):$(GIT_SHA) \
		-dir $(MIGRATION_DIR) up

build-image-promote:
	sudo docker image tag $(BUILD_IMAGE):$(GIT_SHA) $(BUILD_IMAGE):$(BUILD_TAG)
	sudo docker image push $(BUILD_IMAGE):$(BUILD_TAG)

down:
	sudo docker compose down --remove-orphans --volumes

up: down
	sudo docker compose up --detach

migrate:
	goose -dir "$(MIGRATION_DIR)" up

migrate-status:
	goose -dir "$(MIGRATION_DIR)" status

migrate-validate:
	goose -dir "$(MIGRATION_DIR)" validate

start: build
	./goals



