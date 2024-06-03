package rhdh

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/redhat-appstudio/rhtap-cli/pkg/config"
	"github.com/redhat-appstudio/rhtap-cli/pkg/githubapp"
	"github.com/redhat-appstudio/rhtap-cli/pkg/k8s"

	"github.com/google/go-github/scrape"
	"github.com/google/go-github/v60/github"
	"github.com/spf13/pflag"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
)

// GithubIntegration represents the Developer Hub GitHub integration.
type GithubIntegration struct {
	logger *slog.Logger   // application logger
	cfg    *config.Config // installer configuration
	kube   *k8s.Kube      // kubernetes client

	gitHubApp *githubapp.GitHubApp // github app client

	force bool // overwrite the existing secret

	description string // application description
	callbackURL string // github app callback URL
	homepageURL string // github app homepage URL
	webhookURL  string // github app webhook URL
}

// ErrSecretAlreadyExists is returned when the integration secret already exists.
var ErrSecretAlreadyExists = fmt.Errorf("secret already exists")

// PersistentFlags sets the persistent flags for the GitHub integration.
func (g *GithubIntegration) PersistentFlags(p *pflag.FlagSet) {
	p.BoolVar(&g.force, "force", g.force,
		"Overwrite the existing secret")

	p.StringVar(&g.description, "description", g.description,
		"GitHub App description")
	p.StringVar(&g.callbackURL, "callback-url", g.callbackURL,
		"GitHub App callback URL")
	p.StringVar(&g.homepageURL, "homepage-url", g.homepageURL,
		"GitHub App homepage URL")
	p.StringVar(&g.webhookURL, "webhook-url", g.webhookURL,
		"GitHub App webhook URL")
}

// log logger with contextual information.
func (g *GithubIntegration) log() *slog.Logger {
	return g.logger.With(
		"callback-url", g.callbackURL,
		"webhook-url", g.webhookURL,
		"homepage-url", g.homepageURL,
		"force", g.force,
	)
}

// setOpenShiftURLs sets the OpenShift cluster's URLs for the GitHub integration.
// When the URLs are empty it checks the cluster to define them based on the
// installer configuration and current Kubernetes context.
func (g *GithubIntegration) setOpenShiftURLs(ctx context.Context) error {
	ingressDomain, err := k8s.GetOpenShiftIngressDomain(ctx, g.kube)
	if err != nil {
		return err
	}
	g.log().Debug("OpenShift ingress domain", "domain", ingressDomain)

	if g.callbackURL == "" {
		g.callbackURL = fmt.Sprintf(
			"https://developer-hub-%s.%s/api/auth/github/handler/frame",
			g.cfg.Installer.Features.RedHatDeveloperHub.Namespace,
			ingressDomain,
		)
		g.log().Debug("Using OpenShift cluster for GitHub App callback URL")
	}
	if g.webhookURL == "" {
		g.webhookURL = fmt.Sprintf(
			"https://pipelines-as-code-controller-%s.%s",
			g.cfg.Installer.Features.OpenShiftPipelines.Namespace,
			ingressDomain,
		)
		g.log().Debug("Using OpenShift cluster for GitHub App webhook URL")
	}
	if g.homepageURL == "" {
		g.homepageURL = fmt.Sprintf(
			"https://developer-hub-%s.%s",
			g.cfg.Installer.Features.RedHatDeveloperHub.Namespace,
			ingressDomain,
		)
		g.log().Debug("Using OpenShift cluster for GitHub App homepage URL")
	}
	return nil
}

// secretName returns the secret name for the integration. The name is "lazy"
// generated to make sure configuration is already loaded.
func (g *GithubIntegration) secretName() types.NamespacedName {
	return types.NamespacedName{
		Namespace: g.cfg.Installer.Features.RedHatDeveloperHub.Namespace,
		Name:      "rhtap-github-integration",
	}
}

// prepareSecret checks if the secret already exists, and if so, it will delete
// the secret if the force flag is enabled.
func (g *GithubIntegration) prepareSecret(ctx context.Context) error {
	g.log().Debug("Checking if integration secret exists")
	exists, err := k8s.SecretExists(ctx, g.kube, g.secretName())
	if err != nil {
		return err
	}
	if !exists {
		g.log().Debug("Integration secret does not exist")
		return nil
	}
	if !g.force {
		g.log().Debug("Integration secret already exists")
		return fmt.Errorf("%w: %s",
			ErrSecretAlreadyExists, g.secretName().String())
	}
	g.log().Debug("Integration secret already exists, recreating it")
	return k8s.DeleteSecret(ctx, g.kube, g.secretName())
}

// store creates the secret with the integration data.
func (g *GithubIntegration) store(
	ctx context.Context,
	appConfig *github.AppConfig,
) error {
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Namespace: g.secretName().Namespace,
			Name:      g.secretName().Name,
		},
		Type: corev1.SecretTypeOpaque,
		Data: map[string][]byte{
			"clientID":      []byte(*appConfig.ClientID),
			"clientSecret":  []byte(*appConfig.ClientSecret),
			"createdAt":     []byte(github.Stringify(*appConfig.CreatedAt)),
			"externalURL":   []byte(*appConfig.ExternalURL),
			"htmlURL":       []byte(*appConfig.HTMLURL),
			"id":            []byte(github.Stringify(*appConfig.ID)),
			"name":          []byte(*appConfig.Name),
			"nodeID":        []byte(*appConfig.NodeID),
			"owner":         []byte(github.Stringify(*appConfig.Owner)),
			"pem":           []byte(*appConfig.PEM),
			"slug":          []byte(*appConfig.Slug),
			"updatedAt":     []byte(github.Stringify(*appConfig.UpdatedAt)),
			"webhookSecret": []byte(*appConfig.WebhookSecret),
		},
	}
	logger := g.log().With(
		"secret-namespace", secret.GetNamespace(),
		"secret-name", secret.GetName(),
	)

	logger.Debug("Creating integration secret")
	coreClient, err := g.kube.CoreV1ClientSet(g.secretName().Namespace)
	if err != nil {
		return err
	}
	_, err = coreClient.Secrets(g.secretName().Namespace).
		Create(ctx, secret, metav1.CreateOptions{})
	if err == nil {
		logger.Info("Integration secret created successfully!")
	}
	return err
}

// generateAppManifest creates the application manifest for the RHDH GitHub App
func (g *GithubIntegration) generateAppManifest(name string) scrape.AppManifest {
	return scrape.AppManifest{
		Name:           github.String(name),
		URL:            github.String(g.homepageURL),
		Description:    github.String(g.description),
		HookAttributes: map[string]string{"url": g.webhookURL},
		Public:         github.Bool(true),
		DefaultEvents: []string{
			"check_run",
			"check_suite",
			"commit_comment",
			"issue_comment",
			"pull_request",
			"push",
		},
		DefaultPermissions: &github.InstallationPermissions{
			// Permissions for Pipeline-as-Code.
			Checks:           github.String("write"),
			Contents:         github.String("write"),
			Issues:           github.String("write"),
			Members:          github.String("read"),
			Metadata:         github.String("read"),
			OrganizationPlan: github.String("read"),
			PullRequests:     github.String("write"),
			// Permissions for Red Hat Developer Hub (RHDH).
			Administration: github.String("write"),
		},
	}
}

// Create creates the GitHub integration, creating the GitHub App and storing the
// whole application manifest on the cluster, in a Kubernetes secret.
func (g *GithubIntegration) Create(ctx context.Context, name string) error {
	logger := g.log().With("app-name", name)
	logger.Info("Inspecting the cluster forexisting GitHub integration secret")
	if err := g.prepareSecret(ctx); err != nil {
		return err
	}
	logger.Info("Setting the OpenShift based URLs for the GitHub integration")
	if err := g.setOpenShiftURLs(ctx); err != nil {
		return err
	}

	logger.Info("Generating the application manifest", "app-name", name)
	manifest := g.generateAppManifest(name)
	logger.Info("Creating the GitHub App", "app-name", name)
	appConfig, err := g.gitHubApp.Create(ctx, manifest)
	if err != nil {
		return err
	}

	logger.Info("GitHub application created successfully!")
	return g.store(ctx, appConfig)
}

func NewGithubIntegration(
	logger *slog.Logger,
	cfg *config.Config,
	kube *k8s.Kube,
	gitHubApp *githubapp.GitHubApp,
) *GithubIntegration {
	return &GithubIntegration{
		logger:    logger,
		cfg:       cfg,
		kube:      kube,
		gitHubApp: gitHubApp,

		description: "Red Hat Trusted Application Pipeline (RHTAP)",
		force:       false,
		callbackURL: "",
		webhookURL:  "",
		homepageURL: "",
	}
}
