package exporters

import (
	"context"
	"reflect"
	"testing"

	rhtapAPI "github.com/redhat-appstudio/rhtap-cli/api/v1alpha1"
	"github.com/redhat-appstudio/rhtap-cli/cmd/rhtap/commands/config"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

func TestTransformApplication(t *testing.T) {
	type args struct {
		ctx                 context.Context
		fetchedResourceList runtime.Object
		cloneConfig         config.CloneConfig
		localCache          []runtime.Object
	}
	tests := []struct {
		name    string
		args    args
		want    []runtime.Object
		wantErr bool
	}{
		{
			name: "incorrect type",
			args: args{
				ctx:                 context.Background(),
				fetchedResourceList: &rhtapAPI.Component{},
			},
			wantErr: true,
			want:    nil,
		},
		{
			name: "golden path",
			args: args{
				ctx: context.Background(),
				fetchedResourceList: &rhtapAPI.ApplicationList{
					Items: []rhtapAPI.Application{
						{
							ObjectMeta: v1.ObjectMeta{
								Annotations: map[string]string{
									"something-we-dont-need": "a",
								},
							},
						},
					},
				},
			},
			wantErr: false,
			want: []runtime.Object{
				&rhtapAPI.Application{
					ObjectMeta: v1.ObjectMeta{
						Annotations: map[string]string{
							"application.thumbnail": "1",
						},
					},
				},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := TransformApplication(tt.args.ctx, tt.args.fetchedResourceList, tt.args.cloneConfig, tt.args.localCache)
			if (err != nil) != tt.wantErr {
				t.Errorf("TransformApplication() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("TransformApplication() = %v, want %v", got, tt.want)
			}
		})
	}
}
