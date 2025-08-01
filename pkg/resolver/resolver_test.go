package resolver

import (
	"testing"

	"github.com/redhat-appstudio/tssc/pkg/chartfs"
	"github.com/redhat-appstudio/tssc/pkg/config"

	o "github.com/onsi/gomega"
)

func TestNewResolver(t *testing.T) {
	g := o.NewWithT(t)

	cfs, err := chartfs.NewChartFS("../../installer")
	g.Expect(err).To(o.Succeed())

	cfg, err := config.NewConfigFromFile(cfs, "config.yaml")
	g.Expect(err).To(o.Succeed())

	charts, err := cfs.GetAllCharts()
	g.Expect(err).To(o.Succeed())

	c, err := NewCollection(charts)
	g.Expect(err).To(o.Succeed())

	t.Run("Resolve", func(t *testing.T) {
		topology := NewTopology()
		r := NewResolver(cfg, c, topology)

		err := r.Resolve()
		g.Expect(err).To(o.Succeed())

		// Extracting the Helm chart names from the topology.
		names := []string{}
		for _, d := range topology.GetDependencies() {
			names = append(names, d.Chart.Name())
		}
		t.Logf("Resolved dependencies (%d)", len(names))
		for i, name := range names {
			t.Logf("(%2d) %s", i+1, name)
		}
		g.Expect(len(names)).To(o.Equal(14))

		// Validating the order of the resolved dependencies.
		g.Expect(names).To(o.Equal([]string{
			"tssc-openshift",
			"tssc-subscriptions",
			"tssc-infrastructure",
			"tssc-backing-services",
			"tssc-tpa-realm",
			"tssc-tpa",
			"tssc-tas",
			"tssc-pipelines",
			"tssc-gitops",
			"tssc-app-namespaces",
			"tssc-dh",
			"tssc-acs",
			"tssc-acs-test",
			"tssc-integrations",
		}))
	})
}
