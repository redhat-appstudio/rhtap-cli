package integrations

import (
	"context"
	"fmt"
	"log/slog"
	"strings"

	"github.com/redhat-appstudio/rhtap-cli/pkg/config"
	"github.com/redhat-appstudio/rhtap-cli/pkg/k8s"

	"github.com/spf13/pflag"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
)

// ACSIntegration represents the RHTAP ACS integration.
type ACSIntegration struct {
	logger *slog.Logger // application logger
	kube   *k8s.Kube    // kubernetes client

	force bool // overwrite the existing secret

	endpoint string // ACS service endpoint
	token    string // API token credentials
}

// PersistentFlags sets the persistent flags for the ACS integration.
func (a *ACSIntegration) PersistentFlags(p *pflag.FlagSet) {
	p.BoolVar(&a.force, "force", a.force,
		"Overwrite the existing secret")

	p.StringVar(&a.endpoint, "endpoint", a.endpoint,
		"ACS service endpoint, formatted as 'hostname:port'")
	p.StringVar(&a.token, "token", a.token,
		"ACS API token")
}

// log logger with contextual information.
func (a *ACSIntegration) log() *slog.Logger {
	return a.logger.With(
		"force", a.force,
		"endpoint", a.endpoint,
		"token-len", len(a.token),
	)
}

// Validate checks if the required configuration is set.
func (a *ACSIntegration) Validate() error {
	if a.endpoint == "" {
		return fmt.Errorf("endpoint is required")
	}
	if strings.Contains(a.endpoint, "://") {
		return fmt.Errorf("invalid endpoint, the protocol should not be specified")
	}
	if !strings.Contains(a.endpoint, ":") {
		return fmt.Errorf("invalid endpoint, the port should be specified")
	}
	if a.token == "" {
		return fmt.Errorf("token is required")
	}
	return nil
}

// EnsureNamespace ensures the namespace needed for the ACS integration secret
// is created on the cluster.
func (a *ACSIntegration) EnsureNamespace(
	ctx context.Context,
	cfg *config.Config,
) error {
	return k8s.EnsureOpenShiftProject(
		ctx,
		a.log(),
		a.kube,
		cfg.Installer.Namespace,
	)
}

// secretName returns the secret name for the integration. The name is "lazy"
// generated to make sure configuration is already loaded.
func (a *ACSIntegration) secretName(cfg *config.Config) types.NamespacedName {
	return types.NamespacedName{
		Namespace: cfg.Installer.Namespace,
		Name:      "tssc-acs-integration",
	}
}

// prepareSecret checks if the secret already exists, and if so, it will delete
// the secret if the force flag is enabled.
func (a *ACSIntegration) prepareSecret(
	ctx context.Context,
	cfg *config.Config,
) error {
	a.log().Debug("Checking if integration secret exists")
	exists, err := k8s.SecretExists(ctx, a.kube, a.secretName(cfg))
	if err != nil {
		return err
	}
	if !exists {
		a.log().Debug("Integration secret does not exist")
		return nil
	}
	if !a.force {
		a.log().Debug("Integration secret already exists")
		return fmt.Errorf("%w: %s",
			ErrSecretAlreadyExists, a.secretName(cfg).String())
	}
	a.log().Debug("Integration secret already exists, recreating it")
	return k8s.DeleteSecret(ctx, a.kube, a.secretName(cfg))
}

// store creates the secret with the integration data.
func (a *ACSIntegration) store(
	ctx context.Context,
	cfg *config.Config,
) error {
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Namespace: a.secretName(cfg).Namespace,
			Name:      a.secretName(cfg).Name,
		},
		Type: corev1.SecretTypeOpaque,
		Data: map[string][]byte{
			"endpoint": []byte(a.endpoint),
			"token":    []byte(a.token),
		},
	}
	logger := a.log().With(
		"secret-namespace", secret.GetNamespace(),
		"secret-name", secret.GetName(),
	)

	logger.Debug("Creating integration secret")
	coreClient, err := a.kube.CoreV1ClientSet(a.secretName(cfg).Namespace)
	if err != nil {
		return err
	}
	_, err = coreClient.Secrets(a.secretName(cfg).Namespace).
		Create(ctx, secret, metav1.CreateOptions{})
	if err == nil {
		logger.Info("Integration secret created successfully!")
	}
	return err
}

// Create creates the ACS integration Kubernetes secret.
func (a *ACSIntegration) Create(
	ctx context.Context,
	cfg *config.Config,
) error {
	logger := a.log()
	logger.Info("Inspecting the cluster for an existing ACS integration secret")
	if err := a.prepareSecret(ctx, cfg); err != nil {
		return err
	}
	return a.store(ctx, cfg)
}

func NewACSIntegration(
	logger *slog.Logger,
	kube *k8s.Kube,
) *ACSIntegration {
	return &ACSIntegration{
		logger: logger,
		kube:   kube,

		force:    false,
		endpoint: "",
		token:    "",
	}
}
