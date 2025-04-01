package k8s

import (
	"context"
	"strings"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// labelSelector is the label set for resources to be deleted.
const labelSelector = "delete=need-delete"

// nsPrefix is the prefix for all namespaces rhtap installed.
const nsPrefix = "rhtap"

// DeleteClusterRoleBindings deletes Kubernetes ClusterRoleBindings by label.
func DeleteClusterRoleBindings(
	ctx context.Context,
	kube *Kube,
	namespace string,
) error {
	rbacClient, err := kube.RbacV1ClientSet(namespace)
	if err != nil {
		return err
	}
	// Get list of ClusterRoleBindings with label need-delete.
	crbList, err := rbacClient.ClusterRoleBindings().
		List(ctx, metav1.ListOptions{LabelSelector: labelSelector})
	if err != nil {
		return err
	}
	// Delete list of ClusterRoleBindings
	for _, crb := range crbList.Items {
		err = rbacClient.ClusterRoleBindings().Delete(ctx, crb.Name, metav1.DeleteOptions{})
	}
	if err != nil {
		return err
	}
	return nil
}

// DeleteServiceAccount deletes Kubernetes ServiceAccounts by label.
func DeleteServiceAccounts(
	ctx context.Context,
	kube *Kube,
	namespace string,
) error {
	coreClient, err := kube.CoreV1ClientSet(namespace)
	if err != nil {
		return err
	}

	rhtapNamespaces, err := GetNamespaces(ctx, kube, namespace)
	if err != nil {
		return err
	}
	for _, namespace := range rhtapNamespaces {
		// Get list of ServiceAccounts with label need-delete.
		saList, err := coreClient.ServiceAccounts(namespace).
			List(ctx, metav1.ListOptions{LabelSelector: labelSelector})
		if err != nil {
			return err
		}
		// Delete list of ServiceAccounts
		for _, sa := range saList.Items {
			err = coreClient.ServiceAccounts(namespace).
				Delete(ctx, sa.Name, metav1.DeleteOptions{})
		}
	}
	if err != nil {
		return err
	}
	return nil
}

// GetNamespaces get list of namespaces created by RHTAP.
func GetNamespaces(
	ctx context.Context,
	kube *Kube,
	namespace string,
) ([]string, error) {
	coreClient, err := kube.CoreV1ClientSet(namespace)
	if err != nil {
		return nil, err
	}
	// Get list of all the namespaces
	nsList, err := coreClient.Namespaces().
		List(ctx, metav1.ListOptions{})
	if err != nil {
		return nil, err
	}
	var rhtapNamespaces []string
	for _, ns := range nsList.Items {
		if strings.HasPrefix(ns.Name, nsPrefix) {
			rhtapNamespaces = append(rhtapNamespaces, ns.Name)
		}
	}
	return rhtapNamespaces, nil
}

// DeleteResources deletes temporary Kubernetes resources created during deployment.
func DeleteResources(
	ctx context.Context,
	kube *Kube,
	namespace string,
) error {
	// Delete ClusterRoleBindings
	err := DeleteClusterRoleBindings(ctx, kube, namespace)
	if err != nil {
		return err
	}
	// Delete ServiceAccounts
	err = DeleteServiceAccounts(ctx, kube, namespace)
	if err != nil {
		return err
	}
	return nil
}

// Retry defines retry.
func Retry(attempts int, sleep time.Duration, fn func() error) error {
	for i := 0; ; i++ {
		err := fn()
		if err == nil {
			return nil
		}
		if i >= (attempts - 1) {
			return err
		}
		time.Sleep(sleep)
	}
}

// RetryDeleteResources deletes temporary resources with retry 5 times.
func RetryDeleteResources(
	ctx context.Context,
	kube *Kube,
	namespace string,
) error {
	// Delete temporary resources
	err := Retry(5, 10*time.Second, func() error {
		err := DeleteResources(ctx, kube, namespace)
		if err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return err
	}
	return nil
}
