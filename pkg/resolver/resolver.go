package resolver

import (
	"fmt"
	"io"
	"strings"
	"text/tabwriter"

	"github.com/redhat-appstudio/tssc/pkg/config"

	"helm.sh/helm/v3/pkg/chart"
)

// Resolver represents theh actor that resolves dependencies between charts.
type Resolver struct {
	cfg        *config.Config // installer configuration
	collection *Collection    // collection of charts
	topology   *Topology      // topology of dependencies
}

// ErrCircularDependency reports a circular dependency.
var ErrCircularDependency = fmt.Errorf("circular dependency detected")

// dependsOn checks if the chart has dependencies and resolves them. The
// dependencies are prepended to the parent chart and when more dependencies are
// found, they are also resolved.
func (r *Resolver) dependsOn(
	parent string, // partent chart name
	hc *chart.Chart, // helm chart instance
	visited map[string]bool, // visited charts
) error {
	// Ensure the chart is not visited again, to prevent circular dependencies.
	chartName := hc.Name()
	if visited[chartName] {
		return fmt.Errorf("%w: a %q dependency is depedent itself. ",
			ErrCircularDependency, chartName)
	}
	visited[chartName] = true
	defer delete(visited, chartName)

	for _, dependsOn := range r.collection.DependsOn(hc) {
		dependsOnHC, err := r.collection.Get(dependsOn)
		if err != nil {
			return err
		}
		// Skiping when the Helm chart is associated with a disabled product.
		if product := r.collection.ProductName(dependsOnHC); product != "" {
			productSpec, err := r.cfg.GetProduct(product)
			if err != nil {
				return err
			}
			if !productSpec.Enabled {
				continue
			}
		}
		// Adding the Helm chart to the topology before the parent chart. The
		// namespace is the installer's default.
		dep := config.NewDependency(dependsOnHC, r.cfg.Installer.Namespace)
		r.topology.PrependBefore(parent, *dep)
		// Recursively resolving the dependencies.
		if err = r.dependsOn(dependsOn, dependsOnHC, visited); err != nil {
			return err
		}
	}
	return nil
}

// resolveEnabledProducts resolves the dependencies of enabled products.
func (r *Resolver) resolveEnabledProducts() error {
	for _, product := range r.cfg.GetEnabledProducts() {
		hc, err := r.collection.GetProductChart(product.Name)
		if err != nil {
			return err
		}
		// Product charts are added to the topology before required charts.
		r.topology.Append(config.Dependency{
			Chart:     hc,
			Namespace: *product.Namespace,
		})
		// Recursively resolving the dependencies, added before this chart.
		if err = r.dependsOn(hc.Name(), hc, map[string]bool{}); err != nil {
			return err
		}
	}
	return nil
}

// resolveDependencies final inspection of the Helm chrts in the collection to
// ensure all dependencies are met.
func (r *Resolver) resolveDependencies() error {
	return r.collection.Walk(func(name string, hc chart.Chart) error {
		if productName := r.collection.ProductName(&hc); productName != "" {
			return nil
		}
		// Collecting the last Helm chart name that is required by the current
		// chart, if any.
		requiredBy := ""
		for _, dependsOn := range r.collection.DependsOn(&hc) {
			// Skip if the required chart is not in the collection.
			if _, err := r.collection.Get(dependsOn); err != nil {
				continue
			}
			requiredBy = dependsOn
		}
		// If it's not required by any other chart, skip it.
		if requiredBy == "" {
			return nil
		}
		// Append the current chart after the last chart in the collection that
		// required it.
		dep := config.NewDependency(&hc, r.cfg.Installer.Namespace)
		r.topology.AppendAfter(requiredBy, *dep)
		return r.dependsOn(name, &hc, map[string]bool{})
	})
}

// Resolve resolves the dependencies of the charts in the collection generating
// the installer topology.
func (r *Resolver) Resolve() error {
	if err := r.resolveEnabledProducts(); err != nil {
		return err
	}
	return r.resolveDependencies()
}

// Print prints the resolved topology to the writer formatted as a table.
func (r *Resolver) Print(w io.Writer) {
	table := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	row := func(a ...any) {
		fmt.Fprintf(table, "%s\t%s\t%s\t%s\t%s\n", a...)
	}
	row("Index", "Chart", "Namespace", "Product", "Depends-On")
	for i, d := range r.topology.GetDependencies() {
		dependsOn := r.collection.DependsOn(d.Chart)
		row(
			fmt.Sprintf("%2d", i+1),
			d.Chart.Name(),
			d.Namespace,
			r.collection.ProductName(d.Chart),
			strings.Join(dependsOn, ", "),
		)
	}
	table.Flush()
}

// NewResolver instantiates a new Resolver. It takes the configuration, collection
// and topology as parameters.
func NewResolver(cfg *config.Config, c *Collection, t *Topology) *Resolver {
	return &Resolver{
		cfg:        cfg,
		collection: c,
		topology:   t,
	}
}
