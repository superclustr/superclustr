# Variables
BINARY_NAME=convolv
OUT_DIR=bin
DOCKER_IMAGE=golang:1.22
DOCKER_WORKDIR=/usr/src/app

# Docker run command
DOCKER_RUN=docker run --rm -v $(PWD):$(DOCKER_WORKDIR) -w $(DOCKER_WORKDIR) $(DOCKER_IMAGE)

# Default target
all: generate build

# Run generate
generate:
	$(DOCKER_RUN) go generate ./...

# Build the binary
build:
	$(DOCKER_RUN) go build -o $(OUT_DIR)/$(BINARY_NAME) main.go

# Run the binary with arguments
run:
	$(DOCKER_RUN) ./$(OUT_DIR)/$(BINARY_NAME) $(filter-out $@,$(MAKECMDGOALS))

# Test the project
test:
	$(DOCKER_RUN) go test ./...

# Clean up generated files
clean:
	$(DOCKER_RUN) go clean
	rm -f $(BINARY_NAME)

# Tidy up dependencies
tidy:
	$(DOCKER_RUN) go mod tidy

# Update dependencies
update-deps:
	$(DOCKER_RUN) go get -u ./...
	$(DOCKER_RUN) go mod tidy

.PHONY: all generate build run test clean tidy update-deps

# Ignore run arguments as make targets
%:
	@:
