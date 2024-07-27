# Variables
BINARY_NAME=convolv
OUT_DIR=bin

# Default target
all: build

# Build the binary
build:
	go build -o $(OUT_DIR)/$(BINARY_NAME) main.go

# Run the binary
run: build
	./$(BINARY_NAME)

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

.PHONY: all build run test clean tidy update-deps
