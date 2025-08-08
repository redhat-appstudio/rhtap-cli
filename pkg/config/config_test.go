package config

import (
	"testing"

	"github.com/redhat-appstudio/tssc-cli/pkg/chartfs"

	o "github.com/onsi/gomega"
)

func TestNewConfigFromFile(t *testing.T) {
	g := o.NewWithT(t)

	cfs, err := chartfs.NewChartFS("../../installer")
	g.Expect(err).To(o.Succeed())

	cfg, err := NewConfigFromFile(cfs, "config.yaml")
	g.Expect(err).To(o.Succeed())
	g.Expect(cfg).NotTo(o.BeNil())
	g.Expect(cfg.Installer).NotTo(o.BeNil())

	t.Run("Validate", func(t *testing.T) {
		err := cfg.Validate()
		g.Expect(err).To(o.Succeed())
	})

	t.Run("GetEnabledProducts", func(t *testing.T) {
		products := cfg.GetEnabledProducts()
		g.Expect(products).NotTo(o.BeEmpty())
		g.Expect(len(products)).To(o.BeNumerically(">", 1))
	})

	t.Run("GetProduct", func(t *testing.T) {
		_, err := cfg.GetProduct("product1")
		g.Expect(err).NotTo(o.Succeed())

		product, err := cfg.GetProduct("Developer Hub")
		g.Expect(err).To(o.Succeed())
		g.Expect(product).NotTo(o.BeNil())
		g.Expect(product.GetNamespace()).NotTo(o.BeEmpty())
	})

	t.Run("MarshalYAML and UnmarshalYAML", func(t *testing.T) {
		payload, err := cfg.MarshalYAML()
		g.Expect(err).To(o.Succeed())
		g.Expect(string(payload)).To(o.ContainSubstring("tssc:"))

		err = cfg.UnmarshalYAML()
		g.Expect(err).To(o.Succeed())
	})

	t.Run("String", func(t *testing.T) {
		payload := cfg.String()
		g.Expect(string(payload)).To(o.ContainSubstring("tssc:"))
	})
}
