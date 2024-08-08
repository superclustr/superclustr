package main

import (
	"strings"

	"github.com/kluctl/go-embed-python/pip"
)

func main() {
	platforms := map[string][]string{
		"linux-amd64": {"manylinux_2_17_x86_64", "manylinux_2_28_x86_64", "manylinux2014_x86_64"},
		"linux-arm64": {"manylinux_2_17_aarch64", "manylinux_2_28_aarch64", "manylinux2014_aarch64"},
	}

	for goPlatform, pipPlatforms := range platforms {
		s := strings.Split(goPlatform, "-")
		goOs, goArch := s[0], s[1]
		err := pip.CreateEmbeddedPipPackages("requirements.txt", goOs, goArch, pipPlatforms, "./data/")
		if err != nil {
			panic(err)
		}
	}
}
