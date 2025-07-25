package subcmd

import (
	"archive/tar"
	"bytes"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"

	"github.com/redhat-appstudio/tssc/installer"
	"github.com/redhat-appstudio/tssc/pkg/flags"

	"github.com/spf13/cobra"
)

// Installer represents the installer subcommand to list and extract the embedded
// resources used for the installation process.
type Installer struct {
	cmd   *cobra.Command // cobra command
	flags *flags.Flags   // global flags

	list    bool   // list the embedded resources
	extract string // extract into a directory
}

var _ Interface = &Installer{}

const installerDesc = `
Shows the embedded installer resources, and extracts them to a directory.

The installer resources can be inspected, and optionally customized for a specific
installation scenario. Later on power up the installation process using the
'deploy' subcommand.

For instance:

	1. Extract the installer resources to a directory:
		$ mkdir /path/to/directory
		$ tssc installer --list
		$ tssc installer --extract /path/to/directory

	2. Customize the installer resources on '/path/to/directory' and edit the
		'config.yaml' configuration file (in the same directory).

	3. Deploy the customized installer resources:
		$ tssc deploy --config /path/to/directory/config.yaml
`

// dirMode is the default directory permissions.
const dirMode os.FileMode = 0755

// Cmd exposes the cobra instance.
func (i *Installer) Cmd() *cobra.Command {
	return i.cmd
}

// Complete implements Interface.
func (i *Installer) Complete(_ []string) error {
	return nil
}

// Validate validates the informed flags are correct, and the conditions are met.
func (i *Installer) Validate() error {
	if i.list && i.extract != "" {
		return fmt.Errorf("list and extract are mutually exclusive")
	}
	if !i.list && i.extract == "" {
		return fmt.Errorf("either list or extract flags must be set")
	}
	if !i.list && i.extract != "" {
		stat, err := os.Stat(i.extract)
		if err != nil {
			return err
		}
		if !stat.IsDir() {
			return fmt.Errorf("extract target %q must be a directory", i.extract)
		}
	}
	return nil
}

// listResources lists the embedded resources.
func (i *Installer) listResources() error {
	tr := tar.NewReader(bytes.NewReader(installer.InstallerTarball))

	for {
		header, err := tr.Next()
		if err != nil {
			if err == io.EOF {
				break
			}
			return err
		}
		if header.Size == 0 {
			continue
		}
		fmt.Printf("- %q (%d bytes)\n", header.Name, header.Size)
	}
	return nil
}

// extractResources extracts the embedded resources into the base directory.
func (i *Installer) extractResources() error {
	tr := tar.NewReader(bytes.NewReader(installer.InstallerTarball))

	for {
		header, err := tr.Next()
		if err == io.EOF {
			break
		} else if err != nil {
			return err
		}

		target := filepath.Join(i.extract, header.Name)

		err = i.extractResource(target, header, tr)
		if err != nil {
			return err
		}
	}
	return nil
}

// extractResource extracts an embedded resource into the base directory.
func (i *Installer) extractResource(target string, header *tar.Header, tr *tar.Reader) error {

	// Creating the base directory if it does not exist.
	baseDir := filepath.Dir(target)
	if _, err := os.Stat(baseDir); os.IsNotExist(err) {
		fmt.Printf("- Creating base directory %q\n", baseDir)
		if err := os.MkdirAll(baseDir, dirMode); err != nil {
			return err
		}
	}

	switch header.Typeflag {
	case tar.TypeDir:
		fmt.Printf("- Creating directory %q\n", target)
		if err := os.MkdirAll(target, dirMode); err != nil {
			return err
		}
	case tar.TypeReg:
		if err := i.extractFile(target, header, tr); err != nil {
			return err
		}
	case tar.TypeSymlink:
		if err := i.extractSymlink(target, header); err != nil {
			return err
		}
	default:
		log.Printf("Unsupported type: %v in %s", header.Typeflag, header.Name)
	}
	return nil
}

// extractFile extracts an embedded file into the base directory.
func (i *Installer) extractFile(target string, header *tar.Header, tr *tar.Reader) error {
	fmt.Printf("- Extracting %q\n", target)
	f, err := os.OpenFile(
		target,
		os.O_CREATE|os.O_WRONLY|os.O_TRUNC,
		os.FileMode(header.Mode),
	)
	if err != nil {
		return err
	}
	defer f.Close()

	if _, err := io.Copy(f, tr); err != nil {
		return err
	}
	return nil
}

// extractSymlink extracts an embedded symlink into the base directory.
func (i *Installer) extractSymlink(target string, header *tar.Header) error {
	// Checking for existing symlinks and removing them if they point to a
	// different target location.
	if existingTarget, err := os.Readlink(target); err == nil {
		if existingTarget == header.Linkname {
			fmt.Printf(
				"- Symlink %q already exists and points to %q\n",
				target,
				header.Linkname,
			)
			return nil
		} else {
			// Removing the existing symlink if it points to a different
			// target.
			if err := os.Remove(target); err != nil {
				return err
			}
		}
	} else if !os.IsNotExist(err) {
		return err
	}

	fmt.Printf("- Creating symlink %q -> %q\n", target, header.Linkname)
	if err := os.Symlink(header.Linkname, target); err != nil {
		return err
	}
	return nil
}

// Run lists or extracts the embedded resources.
func (i *Installer) Run() error {
	if i.list {
		return i.listResources()
	}
	return i.extractResources()
}

// NewInstaller creates a new installer subcommand.
func NewInstaller(f *flags.Flags) *Installer {
	i := &Installer{
		cmd: &cobra.Command{
			Use:   "installer",
			Short: "Lists or extract the embedded installer resources",
			Long:  installerDesc,
		},
		flags: f,
	}

	p := i.cmd.PersistentFlags()
	p.BoolVar(&i.list, "list", false, "List the embedded installer resources")
	p.StringVar(
		&i.extract,
		"extract",
		"",
		"Extract the embedded installer resources to a directory",
	)
	return i
}
