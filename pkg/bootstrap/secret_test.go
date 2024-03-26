package bootstrap

import (
	"encoding/base64"
	"reflect"
	"testing"

	"github.com/google/go-github/v60/github"
)

func TestBase64EncodeGithubAppConfig(t *testing.T) {
	id := int64(1)
	name := "name"

	appConfig := &github.AppConfig{
		ID:   github.Int64(id),
		Name: github.String(name),
	}

	expectedData := map[string][]byte{
		"ID": []byte(
			base64.StdEncoding.EncodeToString([]byte(github.Stringify(id))),
		),
		"Name": []byte(
			base64.StdEncoding.EncodeToString([]byte(github.Stringify(name))),
		),
	}

	data := base64EncodeGithubAppConfig(appConfig)

	for k, v := range expectedData {
		if !reflect.DeepEqual(v, data[k]) {
			t.Errorf("base64EncodeGithubAppConfig() %s=%q, expected %s=%q",
				k, data[k], k, expectedData[k])
		}
	}
}
