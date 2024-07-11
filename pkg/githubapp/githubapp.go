package githubapp

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"path/filepath"
	"time"

	"github.com/redhat-appstudio/rhtap-cli/pkg/constants"

	"github.com/google/go-github/scrape"
	"github.com/google/go-github/v61/github"
	"github.com/spf13/pflag"
)

// GitHubApp represents a GitHub App, is responsible to provide the necessary
// structure for the GitHub oAuth2 workflow. GitHub Apps are protected with JWT
// web token, thus the oAuth2 workflow uses the (primary) browser to interact with
// 2FA and other GitHub security measures.
type GitHubApp struct {
	logger *slog.Logger // application logger

	gitHubURL     string // GitHub API URL
	gitHubOrgName string // GitHub organization name
	webServerPort int    // local webserver port
}

// defaultPublicGitHubURL is the default URL for public GitHub.
const defaultPublicGitHubURL = "https://github.com"

// PersistentFlags sets the persistent flags for the GitHub App.
func (g *GitHubApp) PersistentFlags(p *pflag.FlagSet) {
	p.StringVar(&g.gitHubURL, "github-url", g.gitHubURL,
		"GitHub URL")
	p.StringVar(&g.gitHubOrgName, "org", g.gitHubOrgName,
		"GitHub organization name")
	p.IntVar(&g.webServerPort, "webserver-port", g.webServerPort,
		"Callback webserver port number")
}

// log logger with contextual information.
func (g *GitHubApp) log() *slog.Logger {
	return g.logger.With(
		"github-url", g.gitHubURL,
		"github-org", g.gitHubOrgName,
		"webserver-port", g.webServerPort,
	)
}

// getGitHubClient returns a GitHub client, either for public GitHub or GitHub
// enterprise.
func (g *GitHubApp) getGitHubClient() (*github.Client, error) {
	if g.gitHubURL == defaultPublicGitHubURL {
		g.log().Debug("using public GitHub API")
		return github.NewClient(nil), nil
	}
	g.log().Debug("using GitHub Enterprise API")
	return github.NewEnterpriseClient(g.gitHubURL, "", nil)
}

// oAuth2Workflow starts the oAuth2 workflow to create a new GitHub App. The user
// is redirected to the GitHub web interface to create the new app, and the
// authorization code is obtained from the callback URL.
func (g *GitHubApp) oAuth2Workflow(
	ctx context.Context,
	manifest scrape.AppManifest,
) (string, error) {
	manifestBytes, err := json.Marshal(manifest)
	if err != nil {
		return "", err
	}

	serveMux := http.NewServeMux()
	oAuthCodeCh := make(chan string, 1)
	// Handling the oAuth callback from GitHub, trying to extract the code from
	// the response. When the code obtained the flow is completed successfully.
	serveMux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		if code != "" {
			g.log().Debug("oAuth code obtained")
			oAuthCodeCh <- code
			g.log().Info("GitHub App successfully created!")
			fmt.Fprintf(w, gitHubAppSuccessfullyCreatedTmpl, *manifest.Name, constants.AppName)
		} else {
			gitHubURL := g.gitHubURL
			// when the GitHub organization name is informed, using it to create
			// the new app. Otherwise the app should either be created for a user,
			// or for a whole GitHub enterprise.
			if g.gitHubOrgName != "" {
				gitHubURL = filepath.Join(
					gitHubURL, "organizations", g.gitHubOrgName)
			}
			g.log().Debug("serving GitHub App creation page", "url", gitHubURL)
			fmt.Fprintf(w, gitHubNewAppForTmpl, gitHubURL, string(manifestBytes))
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
		go func() {
			err := webServer.ListenAndServe()
			if err != nil && !errors.Is(err, http.ErrServerClosed) {
				g.logger.Error(err.Error())
			}
		}()
		g.log().Debug("opening browser", "url", localhostURL)
		go OpenInBrowser(localhostURL)
	}()

	// Waiting for the code, then shutting down the callback webserver.
	code := <-oAuthCodeCh

	// Giving a few seconds for the user to see the success message, with the
	// shared context the server should close when the application is shutting
	// down.
	go func() {
		time.Sleep(3 * time.Second)
		if err := webServer.Shutdown(ctx); err != nil {
			g.logger.Error(err.Error())
		}
	}()

	return code, nil
}

// Create creates a new GitHub App using the provided manifest. The manifest is
// submitted to GitHub using a regular web form to leverate the required OAuth2
// flow.
func (g *GitHubApp) Create(
	ctx context.Context,
	manifest scrape.AppManifest,
) (*github.AppConfig, error) {
	redirectURL := fmt.Sprintf("http://localhost:%d", g.webServerPort)
	manifest.RedirectURL = github.String(redirectURL)

	// Starting the oAuth workflow to interact with the GitHub web UI and create
	// the new GitHub App.
	g.log().Debug("starting oAuth2 workflow", "redirect-url", redirectURL)
	code, err := g.oAuth2Workflow(ctx, manifest)
	if err != nil {
		return nil, err
	}

	// Retrieving the full AppConfig manifest, from GitHub.
	g.log().Debug(
		"oAuth2 workflow is completed, code is obtained",
		"code-len", len(code),
	)
	gp, err := g.getGitHubClient()
	if err != nil {
		return nil, err
	}
	g.log().Debug("Retrieving full AppConfig manifest from GitHub")
	appConfig, _, err := gp.Apps.CompleteAppManifest(ctx, code)
	if err != nil {
		return nil, err
	}
	g.log().Info("GitHub App successfully created!", "app-id", appConfig.GetID())
	return appConfig, nil
}

// NewGitHubApp creates a new GitHub App instance.
func NewGitHubApp(logger *slog.Logger) *GitHubApp {
	return &GitHubApp{
		logger:        logger,
		gitHubURL:     defaultPublicGitHubURL,
		webServerPort: 8228,
	}
}
