package main

import (
	"testing"

	"screenscrab.network/internal/api"
	"tailscale.com/ipn"
	"tailscale.com/ipn/ipnstate"
)

func TestApplyNotifyUpdatesAuthURLAndSignedInState(t *testing.T) {
	url := "https://login.tailscale.com/a/123"
	status := api.Status{State: api.SigningIn, LoginURL: ""}

	notify := ipn.Notify{
		BrowseToURL: &url,
		InitialStatus: &ipnstate.Status{
			BackendState: "Running",
			Self: &ipnstate.PeerStatus{DNSName: "device"},
		},
	}

	status = applyNotify(status, "old", "", notify)

	if status.LoginURL != url {
		t.Fatalf("expected login URL %q, got %q", url, status.LoginURL)
	}
	if status.State != api.SignedIn {
		t.Fatalf("expected signed in state, got %q", status.State)
	}
}
