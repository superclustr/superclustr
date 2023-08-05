# Base-System: A Rocky Linux OS Builder

Base-System is a repository for building customized Rocky Linux OS images.

## Available Image Configurations

- **Node Image** (`rocky-live-node-base.ks`): For ML/AI cluster nodes.
- **PXE Server Image** (`rocky-live-pxe-base.ks`): For network-based booting.

## Getting Started

### Prerequisites

You need the latest version of Docker on your machine.

### Building an Image

Run the `make-image.sh` script with the Kickstart file and image name:

```bash
./make-image.sh -k <your-kickstart-file> -i <your-image-name>
```

The Linux image is stored in the `out` directory at the project's root.

## Continuous Integration

GitHub Actions automatically build images for each `-base.ks` Kickstart file in the `kickstarts` directory when you push to the `main` branch. Docker Buildx is used for multi-platform image builds.

## Contributing

Please read our [Contributing Guidelines](CONTRIBUTING.md) for details on how to contribute to this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details.
