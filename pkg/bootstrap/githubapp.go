package bootstrap

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"path/filepath"

	"github.com/google/go-github/scrape"
	"github.com/google/go-github/v60/github"
	"github.com/spf13/pflag"
)

type GitHubApp struct {
	logger *slog.Logger // application logger
	name   string       // application name

	description   string // application description
	gitHubAPIURL  string // GitHub API URL
	gitHubOrgName string // GitHub organization name
	webServerPort int    // local webserver port

	// update after RHTAP is deployed
	appURL     string // application URL
	webHookURL string // webhook URL
}

// defaultPublicGithub is the default URL for public GitHub.
const defaultPublicGithub = "https://github.com"

// ErrNameNotSet is returned when the application name is not set.
var ErrNameNotSet = errors.New("name not set")

func (g *GitHubApp) PersistentFlags(p *pflag.FlagSet) {
	p.StringVar(&g.description, "description", g.description,
		"GitHub App description")
	p.StringVar(&g.gitHubAPIURL, "api-url", g.gitHubAPIURL,
		"GitHub API URL")
	p.StringVar(&g.gitHubOrgName, "org", g.gitHubOrgName,
		"GitHub organization name")
	p.IntVar(&g.webServerPort, "webserver-port", g.webServerPort,
		"Callback webserver port number")
}

// SetName sets the application name.
func (g *GitHubApp) SetName(name string) {
	g.name = name
}

func (g *GitHubApp) generateManifest(
	homepageURL, redirectURL, webHookURL string,
) ([]byte, error) {
	if g.name == "" {
		return nil, fmt.Errorf("%w: unable to generate manifest", ErrNameNotSet)
	}
	m := scrape.AppManifest{
		Name:           github.String(g.name),
		URL:            github.String(homepageURL),
		Description:    github.String(g.description),
		RedirectURL:    github.String(redirectURL),
		HookAttributes: map[string]string{"url": webHookURL},
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
			Administration:     github.String("write"),
			RepositoryProjects: github.String("write"),
		},
	}

	return json.Marshal(m)
}

func (g *GitHubApp) getGitHubClient() (*github.Client, error) {
	if g.gitHubAPIURL == defaultPublicGithub {
		return github.NewClient(nil), nil
	}
	return github.NewClient(nil).WithEnterpriseURLs(g.gitHubAPIURL, "")
}

func (g *GitHubApp) oAuthWorkflow(manifest []byte) (string, error) {
	serveMux := http.NewServeMux()
	oAuthCodeCh := make(chan string, 1)
	// Handling the oAuth callback from GitHub, trying to extract the code from
	// the response. When the code obtained the flow is completed successfully.
	serveMux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		if code != "" {
			oAuthCodeCh <- code
			fmt.Fprintf(w, gitHubAppSuccessfullyCreatedTmpl, g.name)
		} else {
			gitHubURL := g.gitHubAPIURL
			// when the GitHub organization name is informed, using it to create
			// the new app. Otherwise the app should either be created for a user,
			// or for a whole GitHub enterprise.
			if g.gitHubOrgName != "" {
				gitHubURL = filepath.Join(
					gitHubURL, "organizations", g.gitHubOrgName)
			}
			fmt.Fprintf(w, gitHubNewAppForTmpl, gitHubURL, string(manifest))
		}
	})

	webServer := &http.Server{
		Addr:    fmt.Sprintf("127.0.0.1:%d", g.webServerPort),
		Handler: serveMux,
	}
	// Opening the web browser while listening for the GitHub callback URL in the
	// background, this process should obtain the oAuth code.
	go func() {
		localhostURL := fmt.Sprintf("http://localhost:%d", g.webServerPort)
		fmt.Printf(
			"Opening %q, click on the link to create your new GitHub App\n",
			localhostURL,
		)
		go OpenInBrowser(localhostURL)
		err := webServer.ListenAndServe()
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			g.logger.Error(err.Error())
		}
	}()

	// Waiting for the code, then shutting down the callback webserver.
	code := <-oAuthCodeCh
	if err := webServer.Shutdown(nil); err != nil {
		return "", err
	}
	return code, nil
}

func (g *GitHubApp) Create(ctx context.Context) (*github.AppConfig, error) {
	// Redirect URL for the oAuth flow using this application's webserver.
	redirectURL := fmt.Sprintf("http://localhost:%d", g.webServerPort)
	// To be replaced by real URLs once RHTAP is deployed.
	placeholder := "https://RHTAP-PLACEHOLDER.com"
	// Generating a new app manifest form.
	appManifest, err := g.generateManifest(placeholder, redirectURL, placeholder)
	if err != nil {
		return nil, err
	}
	// Starting the oAuth workflow to interact with the GitHub web UI and create
	// the new GitHub App.
	code, err := g.oAuthWorkflow(appManifest)
	if err != nil {
		return nil, err
	}

	// Retrieving the full AppConfig manifest, from GitHub.
	gp, err := g.getGitHubClient()
	if err != nil {
		return nil, err
	}
	appConfig, _, err := gp.Apps.CompleteAppManifest(ctx, code)
	if err != nil {
		return nil, err
	}
	return appConfig, nil
}

func (g *GitHubApp) Update() error {
	return nil
}

func NewGitHubApp(logger *slog.Logger) *GitHubApp {
	return &GitHubApp{
		logger:        logger,
		description:   "Red Hat Trusted Application Pipeline (RHTAP)",
		gitHubAPIURL:  defaultPublicGithub,
		webServerPort: 8228,
		gitHubOrgName: "",
	}
}
