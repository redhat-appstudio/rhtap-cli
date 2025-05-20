package integrations

import (
	"context"
	"fmt"
	"log/slog"
	"net/url"

	"github.com/redhat-appstudio/rhtap-cli/pkg/config"
	"github.com/redhat-appstudio/rhtap-cli/pkg/githubapp"
	"github.com/redhat-appstudio/rhtap-cli/pkg/k8s"

	"github.com/google/go-github/scrape"
	"github.com/google/go-github/v71/github"
	"github.com/spf13/pflag"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
)

// GithubIntegration represents the Developer Hub GitHub integration.
type GithubIntegration struct {
	logger *slog.Logger // application logger
	kube   *k8s.Kube    // kubernetes client

	gitHubApp *githubapp.GitHubApp // github app client

	force bool // overwrite the existing secret

	description string // application description
	callbackURL string // github app callback URL
	homepageURL string // github app homepage URL
	webhookURL  string // github app webhook URL

	token string // github personal access token
}

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
	p.StringVar(&g.token, "token", g.token,
		"GitHub personal access token")
}

// log logger with contextual information.
func (g *GithubIntegration) log() *slog.Logger {
	return g.logger.With(
		"callback-url", g.callbackURL,
		"webhook-url", g.webhookURL,
		"homepage-url", g.homepageURL,
		"force", g.force,
		"token-len", len(g.token),
	)
}

// Validate checks if the required configuration is set.
func (g *GithubIntegration) Validate() error {
	if g.token == "" {
		return fmt.Errorf("github token is required")
	}
	return g.gitHubApp.Validate()
}

// EnsureNamespace ensures the namespace needed for the GitHub integration secret
// is created on the cluster.
func (g *GithubIntegration) EnsureNamespace(
	ctx context.Context,
	cfg *config.Config,
) error {
	return k8s.EnsureOpenShiftProject(
		ctx,
		g.log(),
		g.kube,
		cfg.Installer.Namespace,
	)
}

// setOpenShiftURLs sets the OpenShift cluster's URLs for the GitHub integration.
// When the URLs are empty it checks the cluster to define them based on the
// installer configuration and current Kubernetes context.
func (g *GithubIntegration) setOpenShiftURLs(
	ctx context.Context,
	cfg *config.Config,
) error {
	ingressDomain, err := k8s.GetOpenShiftIngressDomain(ctx, g.kube)
	if err != nil {
		return err
	}
	g.log().Debug("OpenShift ingress domain", "domain", ingressDomain)

	featureRHDH, err := cfg.GetFeature(config.RedHatDeveloperHub)
	if err != nil {
		return err
	}

	if g.callbackURL == "" {
		g.callbackURL = fmt.Sprintf(
			"https://backstage-developer-hub-%s.%s/api/auth/github/handler/frame",
			featureRHDH.GetNamespace(),
			ingressDomain,
		)
		g.log().Debug("Using OpenShift cluster for GitHub App callback URL")
	}
	if g.webhookURL == "" {
		feature, err := cfg.GetFeature(config.OpenShiftPipelines)
		if err != nil {
			return err
		}
		g.webhookURL = fmt.Sprintf(
			"https://pipelines-as-code-controller-%s.%s",
			feature.GetNamespace(),
			ingressDomain,
		)
		g.log().Debug("Using OpenShift cluster for GitHub App webhook URL")
	}
	if g.homepageURL == "" {
		g.homepageURL = fmt.Sprintf(
			"https://backstage-developer-hub-%s.%s",
			featureRHDH.GetNamespace(),
			ingressDomain,
		)
		g.log().Debug("Using OpenShift cluster for GitHub App homepage URL")
	}
	return nil
}

// secretName returns the secret name for the integration. The name is "lazy"
// generated to make sure configuration is already loaded.
func (g *GithubIntegration) secretName(cfg *config.Config) types.NamespacedName {
	return types.NamespacedName{
		Namespace: cfg.Installer.Namespace,
		Name:      "tssc-github-integration",
	}
}

// prepareSecret checks if the secret already exists, and if so, it will delete
// the secret if the force flag is enabled.
func (g *GithubIntegration) prepareSecret(
	ctx context.Context,
	cfg *config.Config,
) error {
	g.log().Debug("Checking if integration secret exists")
	exists, err := k8s.SecretExists(ctx, g.kube, g.secretName(cfg))
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
			ErrSecretAlreadyExists, g.secretName(cfg).String())
	}
	g.log().Debug("Integration secret already exists, recreating it")
	return k8s.DeleteSecret(ctx, g.kube, g.secretName(cfg))
}

// getCurrentGitHubUser gets the current user name authenticated with github token
func (g *GithubIntegration) getCurrentGitHubUser(ctx context.Context, ghHost string) (string, error) {
	gc := github.NewClient(nil).WithAuthToken(g.token)
	if ghHost != "github.com" {
		ghUrl := fmt.Sprintf("https://%s/api/v3/", ghHost)
		ghuUrl := fmt.Sprintf("https://%s/api/uploads/", ghHost)
		gce, err := gc.WithEnterpriseURLs(ghUrl, ghuUrl)
		if err != nil {
			return "", err
		}
		gc = gce
	}

	user, _, err := gc.Users.Get(ctx, "")
	if err != nil {
		return "", err
	}

	username := user.GetLogin()

	return username, nil
}

// store creates the secret with the integration data.
func (g *GithubIntegration) store(
	ctx context.Context,
	cfg *config.Config,
	appConfig *github.AppConfig,
) error {
	u, err := url.Parse(appConfig.GetHTMLURL())
	if err != nil {
		return err
	}

	// Getting the user name
	username, err := g.getCurrentGitHubUser(ctx, u.Hostname())
	if err != nil {
		return err
	}

	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Namespace: g.secretName(cfg).Namespace,
			Name:      g.secretName(cfg).Name,
		},
		Type: corev1.SecretTypeOpaque,
		Data: map[string][]byte{
			"clientId":      []byte(appConfig.GetClientID()),
			"clientSecret":  []byte(appConfig.GetClientSecret()),
			"createdAt":     []byte(appConfig.CreatedAt.String()),
			"externalURL":   []byte(appConfig.GetExternalURL()),
			"htmlURL":       []byte(appConfig.GetHTMLURL()),
			"host":          []byte(u.Hostname()),
			"id":            []byte(github.Stringify(appConfig.GetID())),
			"name":          []byte(appConfig.GetName()),
			"nodeId":        []byte(appConfig.GetNodeID()),
			"ownerLogin":    []byte(appConfig.Owner.GetLogin()),
			"ownerId":       []byte(github.Stringify(appConfig.Owner.GetID())),
			"pem":           []byte(appConfig.GetPEM()),
			"slug":          []byte(appConfig.GetSlug()),
			"updatedAt":     []byte(appConfig.UpdatedAt.String()),
			"webhookSecret": []byte(appConfig.GetWebhookSecret()),
			"token":         []byte(g.token),
			"username":      []byte(username),
		},
	}
	logger := g.log().With(
		"secret-namespace", secret.GetNamespace(),
		"secret-name", secret.GetName(),
	)

	logger.Debug("Creating integration secret")
	coreClient, err := g.kube.CoreV1ClientSet(g.secretName(cfg).Namespace)
	if err != nil {
		return err
	}
	_, err = coreClient.Secrets(g.secretName(cfg).Namespace).
		Create(ctx, secret, metav1.CreateOptions{})
	if err == nil {
		logger.Info("Integration secret created successfully!")
	}
	return err
}

// generateAppManifest creates the application manifest for the RHDH GitHub App
func (g *GithubIntegration) generateAppManifest(name string) scrape.AppManifest {
	return scrape.AppManifest{
		Name: github.Ptr(name),
		URL:  github.Ptr(g.homepageURL),
		CallbackURLs: []string{
			g.callbackURL,
		},
		Description:    github.Ptr(g.description),
		HookAttributes: map[string]string{"url": g.webhookURL},
		Public:         github.Ptr(true),
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
			Checks:           github.Ptr("write"),
			Contents:         github.Ptr("write"),
			Issues:           github.Ptr("write"),
			Members:          github.Ptr("read"),
			Metadata:         github.Ptr("read"),
			OrganizationPlan: github.Ptr("read"),
			PullRequests:     github.Ptr("write"),
			// Permissions for Red Hat Developer Hub (RHDH).
			Administration: github.Ptr("write"),
			Workflows:      github.Ptr("write"),
		},
	}
}

// Create creates the GitHub integration, creating the GitHub App and storing the
// whole application manifest on the cluster, in a Kubernetes secret.
func (g *GithubIntegration) Create(
	ctx context.Context,
	cfg *config.Config,
	name string,
) error {
	logger := g.log().With("app-name", name)
	logger.Info("Inspecting the cluster forexisting GitHub integration secret")
	if err := g.prepareSecret(ctx, cfg); err != nil {
		return err
	}
	logger.Info("Setting the OpenShift based URLs for the GitHub integration")
	if err := g.setOpenShiftURLs(ctx, cfg); err != nil {
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
	return g.store(ctx, cfg, appConfig)
}

func NewGithubIntegration(
	logger *slog.Logger,
	kube *k8s.Kube,
	gitHubApp *githubapp.GitHubApp,
) *GithubIntegration {
	return &GithubIntegration{
		logger:    logger,
		kube:      kube,
		gitHubApp: gitHubApp,

		description: "Trusted Software Supply Chain (TSSC)",
		force:       false,
		callbackURL: "",
		webhookURL:  "",
		homepageURL: "",
		token:       "",
	}
}
