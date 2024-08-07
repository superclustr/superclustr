# Variables
BINARY_NAME=convolv
OUT_DIR=bin

# Default target
all: generate build

# Run generate
generate:
	go generate ./...

# Build the binary
build:
	go build -o $(OUT_DIR)/$(BINARY_NAME) main.go

# Run the binary with arguments
run: all
	./$(OUT_DIR)/$(BINARY_NAME) $(filter-out $@,$(MAKECMDGOALS))

# Test the project
test:
	go test ./...

# Clean up generated files
clean:
	go clean
	rm -f $(BINARY_NAME)

# Tidy up dependencies
tidy:
	go mod tidy

# Update dependencies
update-deps:
	go get -u ./...
	go mod tidy

.PHONY: all generate build run test clean tidy update-deps

# Ignore run arguments as make targets
%:
	@: