package config

import (
	"errors"
	"fmt"
	"log/slog"
	"os"

	"github.com/spf13/pflag"
	"gopkg.in/yaml.v3"
)

// ErrInvalidConfig indicates the configuration content is invalid.
var ErrInvalidConfig = errors.New("invalid configuration")

// ErrEmptyConfig indicates the configuration file is empty.
var ErrEmptyConfig = errors.New("empty configuration")

// ErrUnmarshalConfig indicates the configuration file structure is invalid.
var ErrUnmarshalConfig = errors.New("failed to unmarshal configuration")

// FeatureSpec contains the configuration for a specific feature.
type FeatureSpec struct {
	// Enabled feature toggle.
	Enabled bool `yaml:"enabled"`
	// Namespace target namespace for the feature, which may involve different
	// Helm charts targeting the specific feature namespace, while the chart
	// target is deployed in a different namespace.
	Namespace string `yaml:"namespace"`
}

// Features contains the configuration for the installer features.
type Features struct {
	// CRC Code Ready Containers (CRC).
	CRC FeatureSpec `yaml:"crc"`
	// Keycloak Keycloak IAM/SSO.
	Keycloak FeatureSpec `yaml:"keycloak"`
	// TrustedProfileAnalyzer Trusted Profile Analyzer (TPA).
	TrustedProfileAnalyzer FeatureSpec `yaml:"trustedProfileAnalyzer"`
	// TrustedArtifactSigner Trusted Artifact Signer (TAS).
	TrustedArtifactSigner FeatureSpec `yaml:"trustedArtifactSigner"`
	// RedHatDeveloperHub Red Hat Developer Hub (RHDH).
	RedHatDeveloperHub FeatureSpec `yaml:"redHatDeveloperHub"`
	// RedHatQuay Red Hat Quay (RHDH).
	RedHatQuay FeatureSpec `yaml:"redHatQuay"`
	// OpenShiftPipelines OpenShift Pipelines.
	OpenShiftPipelines FeatureSpec `yaml:"openShiftPipelines"`
}

// Dependency contains a individual Helm chart configuration.
type Dependency struct {
	// Chart relative location to the Helm chart directory.
	Chart string `yaml:"chart"`
	// Namespace where the Helm chart will be deployed.
	Namespace string `yaml:"namespace"`
	// Enabled Helm Chart toggle.
	Enabled bool `yaml:"enabled"`
}

// LoggerWith returns a logger with Dependency contextual information.
func (d *Dependency) LoggerWith(logger *slog.Logger) *slog.Logger {
	return logger.With(
		"dep-chart", d.Chart,
		"dep-namespace", d.Namespace,
		"dep-enabled", d.Enabled,
	)
}

// Spec contains all configuration sections.
type Spec struct {
	// Namespace installer's namespace, where the installer's resources will be
	// deployed. Note, Helm charts deployed by the installer are likely to use a
	// different namespace.
	Namespace string `yaml:"namespace"`
	// Features contains the configuration for the installer features.
	Features Features `yaml:"features"`
	// Dependencies contains the installer Helm chart dependencies.
	Dependencies []Dependency `yaml:"dependencies"`
}

// Config root configuration structure.
type Config struct {
	// configPath is the path to the configuration file, private attribute.
	configPath string
	// Installer is the root configuration for the installer.
	Installer Spec `yaml:"rhtapInstallerCLI"`
}

// PersistentFlags defines the persistent flags for the CLI.
func (c *Config) PersistentFlags(f *pflag.FlagSet) {
	f.StringVar(
		&c.configPath,
		"config",
		c.configPath,
		"Path to the installer configuration file",
	)
}

// Validate validates the configuration, checking for missing fields.
func (c *Config) Validate() error {
	root := c.Installer
	if root.Namespace == "" {
		return fmt.Errorf("%w: missing namespace", ErrInvalidConfig)
	}
	if root.Features.Keycloak.Enabled && root.Features.Keycloak.Namespace == "" {
		return fmt.Errorf("%w: missing namespace for Keycloak", ErrInvalidConfig)
	}
	if root.Features.TrustedProfileAnalyzer.Enabled &&
		root.Features.TrustedProfileAnalyzer.Namespace == "" {
		return fmt.Errorf(
			"%w: missing namespace for TrustedProfileAnalyzer", ErrInvalidConfig)
	}
	if root.Features.TrustedArtifactSigner.Enabled &&
		root.Features.TrustedArtifactSigner.Namespace == "" {
		return fmt.Errorf(
			"%w: missing namespace for TrustedArtifactSigner", ErrInvalidConfig)
	}
	if root.Features.OpenShiftPipelines.Enabled &&
		root.Features.OpenShiftPipelines.Namespace == "" {
		return fmt.Errorf(
			"%w: missing namespace for OpenShiftPipelines", ErrInvalidConfig)
	}
	if len(root.Dependencies) == 0 {
		return fmt.Errorf("%w: missing dependencies", ErrInvalidConfig)
	}
	for pos, dep := range root.Dependencies {
		if dep.Chart == "" {
			return fmt.Errorf(
				"%w: missing chart in dependency %d", ErrInvalidConfig, pos)
		}
		if dep.Namespace == "" {
			return fmt.Errorf(
				"%w: missing namespace in dependency %d", ErrInvalidConfig, pos)
		}
	}
	return nil
}

// UnmarshalYAML reads the configuration file and unmarshal it into the Config.
func (c *Config) UnmarshalYAML() error {
	payload, err := os.ReadFile(c.configPath)
	if err != nil {
		return err
	}
	if len(payload) == 0 {
		return fmt.Errorf("%w: %s", ErrEmptyConfig, c.configPath)
	}
	if err = yaml.Unmarshal(payload, c); err != nil {
		return fmt.Errorf("%w: %s %w", ErrUnmarshalConfig, c.configPath, err)
	}
	return c.Validate()
}

// GetEnabledDependencies returns a list of enabled dependencies.
func (c *Config) GetEnabledDependencies(logger *slog.Logger) []Dependency {
	enabled := []Dependency{}
	logger.Debug("Getting enabled dependencies")
	for _, dep := range c.Installer.Dependencies {
		if dep.Enabled {
			logger.Debug("Using dependency...", "dep-chart", dep.Chart)
			enabled = append(enabled, dep)
		} else {
			logger.Debug("Skipping dependency...", "dep-chart", dep.Chart)
		}
	}
	return enabled
}

// NewConfigFromFile returns a new Config instance based on the informed file. The
// config file path is kept as a private attribute.
func NewConfigFromFile(configPath string) (*Config, error) {
	c := &Config{configPath: configPath}
	return c, c.UnmarshalYAML()
}

// NewConfig returns a new Config instance, pointing to the default "config.yaml"
// file location.
func NewConfig() *Config {
	return &Config{configPath: "config.yaml"}
}
