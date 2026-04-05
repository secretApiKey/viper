package main

import (
	"embed"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

const (
	defaultTarget     = "/etc/ErwanSSH"
	defaultCompatLink = ""
)

//go:embed ErwanSSH/**
var runtimeFS embed.FS

func main() {
	target := flag.String("target", defaultTarget, "install target for the bundled ErwanSSH runtime")
	compat := flag.String("compat-link", defaultCompatLink, "optional compatibility symlink")
	force := flag.Bool("force", false, "overwrite existing target contents")
	showBanner := flag.Bool("banner", false, "print the expected SSH banner and exit")
	flag.Parse()

	if *showBanner {
        fmt.Println("SSH-2.0-Paid_Script")
		return
	}

	if os.Geteuid() != 0 {
		fmt.Fprintln(os.Stderr, "please run as root")
		os.Exit(1)
	}

	if err := prepareTarget(*target, *force); err != nil {
		fmt.Fprintf(os.Stderr, "prepare target: %v\n", err)
		os.Exit(1)
	}

	if err := extractBundle(*target); err != nil {
		fmt.Fprintf(os.Stderr, "extract bundle: %v\n", err)
		os.Exit(1)
	}

	if *compat != "" {
		if err := os.RemoveAll(*compat); err != nil && !os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "remove compat link: %v\n", err)
			os.Exit(1)
		}
		if err := os.Symlink(*target, *compat); err != nil {
			fmt.Fprintf(os.Stderr, "create compat symlink: %v\n", err)
			os.Exit(1)
		}
	}

	fmt.Printf("ErwanSSH installed to %s\n", *target)
	if *compat != "" {
		fmt.Printf("Compatibility symlink: %s -> %s\n", *compat, *target)
	}
    fmt.Println("Expected SSH banner: SSH-2.0-Paid_Script")
}

func prepareTarget(target string, force bool) error {
	if info, err := os.Stat(target); err == nil {
		if !info.IsDir() {
			return fmt.Errorf("%s exists and is not a directory", target)
		}
		if !force {
			return fmt.Errorf("%s already exists; rerun with -force to replace it", target)
		}
		if err := os.RemoveAll(target); err != nil {
			return err
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	return os.MkdirAll(target, 0o755)
}

func extractBundle(target string) error {
	return fs.WalkDir(runtimeFS, "ErwanSSH", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel := strings.TrimPrefix(path, "ErwanSSH")
		rel = strings.TrimPrefix(rel, "/")
		if rel == "" {
			return nil
		}
		dst := filepath.Join(target, filepath.FromSlash(rel))
		if d.IsDir() {
			return os.MkdirAll(dst, dirMode(rel))
		}
		data, err := runtimeFS.ReadFile(path)
		if err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return err
		}
		if err := os.WriteFile(dst, data, fileMode(rel)); err != nil {
			return err
		}
		return nil
	})
}

func dirMode(rel string) os.FileMode {
	if strings.HasPrefix(rel, "var/") {
		return 0o755
	}
	return 0o755
}

func fileMode(rel string) os.FileMode {
	slashRel := filepath.ToSlash(rel)
	switch {
	case strings.HasPrefix(slashRel, "bin/"),
		strings.HasPrefix(slashRel, "sbin/"),
		strings.HasPrefix(slashRel, "libexec/"):
		return 0o755
	case strings.HasPrefix(slashRel, "etc/ssh_host_") && strings.HasSuffix(slashRel, "_key"):
		return 0o600
	default:
		return 0o644
	}
}
