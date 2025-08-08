package config

import (
	"log/slog"

	"helm.sh/helm/v3/pkg/chart"
)

// Dependency contains a individual Helm chart configuration.
type Dependency struct {
	// Chart relative location to the Helm chart directory.
	Chart *chart.Chart
	// Namespace where the Helm chart will be deployed.
	Namespace string
}

// LoggerWith decorates the logger with dependency information.
func (d *Dependency) LoggerWith(logger *slog.Logger) *slog.Logger {
	return logger.With("dep-chart", d.Chart.Name(), "dep-namespace", d.Namespace)
}

// NewDependency creates a new Dependency instance.
func NewDependency(chart *chart.Chart, namespace string) *Dependency {
	return &Dependency{
		Chart:     chart,
		Namespace: namespace,
	}
}
