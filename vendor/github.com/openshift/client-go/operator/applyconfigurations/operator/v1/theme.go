// Code generated by applyconfiguration-gen. DO NOT EDIT.

package v1

import (
	operatorv1 "github.com/openshift/api/operator/v1"
)

// ThemeApplyConfiguration represents a declarative configuration of the Theme type for use
// with apply.
type ThemeApplyConfiguration struct {
	Mode   *operatorv1.ThemeMode                  `json:"mode,omitempty"`
	Source *FileReferenceSourceApplyConfiguration `json:"source,omitempty"`
}

// ThemeApplyConfiguration constructs a declarative configuration of the Theme type for use with
// apply.
func Theme() *ThemeApplyConfiguration {
	return &ThemeApplyConfiguration{}
}

// WithMode sets the Mode field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the Mode field is set to the value of the last call.
func (b *ThemeApplyConfiguration) WithMode(value operatorv1.ThemeMode) *ThemeApplyConfiguration {
	b.Mode = &value
	return b
}

// WithSource sets the Source field in the declarative configuration to the given value
// and returns the receiver, so that objects can be built by chaining "With" function invocations.
// If called multiple times, the Source field is set to the value of the last call.
func (b *ThemeApplyConfiguration) WithSource(value *FileReferenceSourceApplyConfiguration) *ThemeApplyConfiguration {
	b.Source = value
	return b
}
