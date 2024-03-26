package bootstrap

import (
	"context"
	"encoding/base64"
	"reflect"

	"github.com/otaviof/rhtap-installer-cli/pkg/k8s"

	"github.com/google/go-github/v60/github"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
)

// base64EncodeGithubAppConfig converts each field of AppConfig to a base64
// encoded string.
func base64EncodeGithubAppConfig(appConfig *github.AppConfig) map[string][]byte {
	data := make(map[string][]byte)
	val := reflect.ValueOf(appConfig).Elem()
	for i := 0; i < val.NumField(); i++ {
		k := val.Type().Field(i).Name
		v := github.Stringify(val.Field(i).Interface())
		data[k] = []byte(base64.StdEncoding.EncodeToString([]byte(v)))
	}
	return data
}

func CreateGitHubAppConfigSecret(
	ctx context.Context,
	kube *k8s.Kube,
	secretName types.NamespacedName,
	appConfig *github.AppConfig,
) error {
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Namespace: secretName.Namespace,
			Name:      secretName.Name,
		},
		Type: corev1.SecretTypeOpaque,
		Data: base64EncodeGithubAppConfig(appConfig),
	}

	clientset, err := kube.ClientSet(secretName.Namespace)
	if err != nil {
		return err
	}
	_, err = clientset.CoreV1().
		Secrets(secretName.Namespace).
		Create(ctx, secret, metav1.CreateOptions{})
	return err
}
