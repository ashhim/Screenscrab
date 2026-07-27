package main

/*
#include <stdint.h>
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/netip"
	"os"
	"strings"
	"sync"
	"time"
	"unsafe"

	"screenscrab.network/internal/api"

	"tailscale.com/client/local"
	"tailscale.com/ipn"
	"tailscale.com/ipn/ipnstate"
	"tailscale.com/tsnet"
)

type connHandle struct {
	conn net.Conn
}

type runtimeState struct {
	mu        sync.Mutex
	started   bool
	server    *tsnet.Server
	local     *local.Client
	authURL   string
	lastError string
	nextID    uint64
	conns     map[uint64]*connHandle
	status    api.Status
	watcher   *local.IPNBusWatcher
}

var state = &runtimeState{
	status: api.Status{
		State: api.Offline,
		Identity: api.Identity{
			DeviceName: "Screenscrab",
			DeviceID:   "pending",
		},
		Peers:         []api.Peer{},
		LastError:     "network runtime not started",
		Reconnectable: true,
	},
	conns: map[uint64]*connHandle{},
}

func cstr(s string) *C.char { return C.CString(s) }

func freeCBuffer(_ unsafe.Pointer) {}

func firstIP(ips []netip.Addr) string {
	if len(ips) == 0 {
		return ""
	}
	return ips[0].String()
}

func toStatusJSON(st *ipnstate.Status, authURL, lastError string) api.Status {
	status := api.Status{
		State:           api.SignedIn,
		LastError:       lastError,
		LoginURL:        authURL,
		Reconnectable:   true,
		Identity:        api.Identity{},
		Peers:           []api.Peer{},
		PeerCount:       0,
	}
	if st == nil {
		status.State = api.Offline
		return status
	}
	if st.BackendState == "NeedsLogin" || st.BackendState == "NeedsMachineAuth" {
		status.State = api.SigningIn
	} else if st.BackendState == "Starting" {
		status.State = api.Retrying
	} else if st.BackendState == "Stopped" || st.BackendState == "NoState" {
		status.State = api.Offline
	}
	if st.Self != nil {
		status.Identity = api.Identity{
			AccountEmail: "",
			TailnetName:  "",
			DeviceName:   st.Self.DNSName,
			DeviceID:     fmt.Sprint(st.Self.NodeID),
			TailscaleIP:  firstIP(st.Self.TailscaleIPs),
			SignedIn:     st.BackendState == "Running",
		}
	}
	if st.CurrentTailnet != nil {
		status.Identity.TailnetName = st.CurrentTailnet.Name
	}
	if len(st.User) > 0 && st.Self != nil {
		if u, ok := st.User[st.Self.UserID]; ok {
			status.Identity.AccountEmail = u.LoginName
		}
	}
	peers := make([]api.Peer, 0, len(st.Peer))
	for _, peer := range st.Peer {
		latency := uint32(0)
		if !peer.LastHandshake.IsZero() {
			latency = uint32(time.Since(peer.LastHandshake).Milliseconds())
			if latency > 0xFFFFFFFF {
				latency = 0xFFFFFFFF
			}
		}
		peers = append(peers, api.Peer{
			NodeID:    fmt.Sprint(peer.NodeID),
			Name:      peer.DNSName,
			Address:   firstIP(peer.TailscaleIPs),
			Platform:  peer.OS,
			Online:    peer.Online,
			LatencyMS: latency,
			Quality:   uint32(peer.RxBytes + peer.TxBytes),
		})
	}
	status.Peers = peers
	status.PeerCount = len(peers)
	return status
}

func applyNotify(current api.Status, authURL, lastError string, notify ipn.Notify) api.Status {
	if notify.BrowseToURL != nil && *notify.BrowseToURL != "" {
		authURL = *notify.BrowseToURL
	}
	if notify.InitialStatus != nil {
		current = toStatusJSON(notify.InitialStatus, authURL, lastError)
	} else if notify.State != nil {
		current.State = api.State(notify.State.String())
	}
	if current.State == api.SignedIn || current.State == api.SigningIn || current.State == api.Connected || current.State == api.Retrying {
		current.LoginURL = authURL
	}
	return current
}

func (r *runtimeState) refreshLocked(ctx context.Context) {
	if r.local == nil {
		r.status.State = api.Offline
		return
	}
	st, err := r.local.Status(ctx)
	if err != nil {
		r.lastError = err.Error()
		r.status.State = api.Error
		r.status.LastError = r.lastError
		return
	}
	r.status = toStatusJSON(st, r.authURL, r.lastError)
}

func (r *runtimeState) watchIPNLocked(ctx context.Context) error {
	if r.local == nil || r.watcher != nil {
		return nil
	}
	watcher, err := r.local.WatchIPNBus(ctx, 0)
	if err != nil {
		return err
	}
	r.watcher = watcher
	go func() {
		for {
			notify, err := watcher.Next()
			if err != nil {
				return
			}
			r.mu.Lock()
			if r.local == nil {
				r.mu.Unlock()
				return
			}
			if notify.BrowseToURL != nil && *notify.BrowseToURL != "" {
				r.authURL = *notify.BrowseToURL
			}
			if notify.InitialStatus != nil {
				r.status = toStatusJSON(notify.InitialStatus, r.authURL, r.lastError)
			} else if notify.State != nil {
				r.status.State = api.State(notify.State.String())
			}
			if r.status.State == api.SignedIn || r.status.State == api.SigningIn || r.status.State == api.Connected || r.status.State == api.Retrying {
				r.status.LoginURL = r.authURL
			}
			if r.status.State == api.SignedIn && r.status.Identity.SignedIn == false && notify.InitialStatus != nil && notify.InitialStatus.Self != nil {
				r.status.Identity.SignedIn = true
			}
			if r.watcher == watcher {
				if r.status.State == api.SignedIn {
					r.status.LastError = ""
				}
			}
			r.mu.Unlock()
		}
	}()
	return nil
}

func (r *runtimeState) startLocked() error {
	if r.started {
		return nil
	}
	srv := &tsnet.Server{
		Hostname: "screenscrab",
		Dir:      filepathJoinUserConfig("Screenscrab"),
		UserLogf: func(format string, args ...any) {
			msg := fmt.Sprintf(format, args...)
			if strings.Contains(msg, "auth") || strings.Contains(msg, "login") {
				r.authURL = msg
			}
		},
	}
	if key := os.Getenv("SCREENSCRAB_TS_AUTHKEY"); key != "" {
		srv.AuthKey = key
	}
	if err := srv.Start(); err != nil {
		return err
	}
	lc, err := srv.LocalClient()
	if err != nil {
		_ = srv.Close()
		return err
	}
	r.server = srv
	r.local = lc
	r.started = true
	if err := r.watchIPNLocked(context.Background()); err != nil {
		_ = srv.Close()
		r.server = nil
		r.local = nil
		r.started = false
		return err
	}
	if err := lc.StartLoginInteractive(context.Background()); err != nil {
		r.lastError = err.Error()
		r.status.State = api.Error
		r.status.LastError = r.lastError
		return err
	}
	r.status.State = api.SigningIn
	r.status.LastError = ""
	r.status.LoginURL = r.authURL
	return nil
}

func filepathJoinUserConfig(parts ...string) string {
	base, err := os.UserConfigDir()
	if err != nil {
		return "Screenscrab"
	}
	path := base
	for _, p := range parts {
		path += string(os.PathSeparator) + p
	}
	return path
}

func (r *runtimeState) stopLocked() {
	for id, c := range r.conns {
		if c != nil && c.conn != nil {
			_ = c.conn.Close()
		}
		delete(r.conns, id)
	}
	if r.server != nil {
		_ = r.server.Close()
	}
	if r.watcher != nil {
		_ = r.watcher.Close()
		r.watcher = nil
	}
	if r.watcher != nil {
		_ = r.watcher.Close()
		r.watcher = nil
	}
	r.server = nil
	r.local = nil
	r.started = false
	r.authURL = ""
	r.status = api.Status{
		State: api.Offline,
		Identity: api.Identity{
			DeviceName: "Screenscrab",
			DeviceID:   "pending",
		},
		Peers:         []api.Peer{},
		LastError:     "network stopped",
		Reconnectable: true,
	}
}

func wrapCall(fn func() C.int) C.int {
	return fn()
}

//export Network_Start
func Network_Start() C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	if err := state.startLocked(); err != nil {
		state.lastError = err.Error()
		state.status.State = api.Error
		state.status.LastError = state.lastError
		return -1
	}
	return 0
}

//export Network_Stop
func Network_Stop() C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	state.stopLocked()
	return 0
}

//export Network_Login
func Network_Login() C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	if err := state.startLocked(); err != nil {
		state.lastError = err.Error()
		state.status.State = api.Error
		state.status.LastError = state.lastError
		return -1
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	state.refreshLocked(ctx)
	return 0
}

//export Network_Logout
func Network_Logout() C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	if state.local != nil {
		_ = state.local.Logout(context.Background())
	}
	state.stopLocked()
	return 0
}

//export Network_GetStatus
func Network_GetStatus() *C.char {
	state.mu.Lock()
	defer state.mu.Unlock()
	payload, _ := json.Marshal(state.status)
	return cstr(string(payload))
}

//export Network_GetIdentity
func Network_GetIdentity() *C.char {
	state.mu.Lock()
	defer state.mu.Unlock()
	payload, _ := json.Marshal(state.status.Identity)
	return cstr(string(payload))
}

//export Network_GetPeers
func Network_GetPeers() *C.char {
	state.mu.Lock()
	defer state.mu.Unlock()
	payload, _ := json.Marshal(state.status.Peers)
	return cstr(string(payload))
}

//export Network_ConnectPeer
func Network_ConnectPeer(peerName *C.char, port C.uint16_t) C.int {
	if peerName == nil {
		return -1
	}
	state.mu.Lock()
	defer state.mu.Unlock()
	if state.local == nil {
		return -1
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	conn, err := state.local.DialTCP(ctx, C.GoString(peerName), uint16(port))
	if err != nil {
		state.lastError = err.Error()
		state.status.LastError = state.lastError
		state.status.State = api.Error
		return -1
	}
	state.nextID++
	state.conns[state.nextID] = &connHandle{conn: conn}
	state.status.State = api.Connected
	return C.int(state.nextID)
}

//export Network_Disconnect
func Network_Disconnect(connID C.uint64_t) C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	handle := state.conns[uint64(connID)]
	if handle == nil || handle.conn == nil {
		return -1
	}
	_ = handle.conn.Close()
	delete(state.conns, uint64(connID))
	state.status.State = api.SignedIn
	return 0
}

//export Network_Send
func Network_Send(connID C.uint64_t, data unsafe.Pointer, size C.uint32_t) C.int {
	if data == nil || size == 0 {
		return -1
	}
	state.mu.Lock()
	handle := state.conns[uint64(connID)]
	state.mu.Unlock()
	if handle == nil || handle.conn == nil {
		return -1
	}
	buf := unsafe.Slice((*byte)(data), int(size))
	n, err := handle.conn.Write(buf)
	if err != nil {
		return -1
	}
	return C.int(n)
}

//export Network_Receive
func Network_Receive(connID C.uint64_t, data unsafe.Pointer, size C.uint32_t) C.int {
	if data == nil || size == 0 {
		return -1
	}
	state.mu.Lock()
	handle := state.conns[uint64(connID)]
	state.mu.Unlock()
	if handle == nil || handle.conn == nil {
		return -1
	}
	buf := unsafe.Slice((*byte)(data), int(size))
	n, err := handle.conn.Read(buf)
	if err != nil {
		return -1
	}
	return C.int(n)
}

//export Network_FreeBuffer
func Network_FreeBuffer(ptr unsafe.Pointer) {
	C.free(ptr)
}

//export Network_GetLastError
func Network_GetLastError() *C.char {
	state.mu.Lock()
	defer state.mu.Unlock()
	if state.lastError == "" {
		return cstr("")
	}
	return cstr(state.lastError)
}

//export Network_Refresh
func Network_Refresh() C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	state.refreshLocked(ctx)
	return 0
}

//export Network_Reconnect
func Network_Reconnect() C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	if state.local != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		state.refreshLocked(ctx)
		return 0
	}
	return -1
}

//export Network_GetAuthURL
func Network_GetAuthURL() *C.char {
	state.mu.Lock()
	defer state.mu.Unlock()
	return cstr(state.authURL)
}

// Legacy aliases kept for the existing C++ bridge.
//export screencrab_network_api_version
func screencrab_network_api_version() C.uint32_t { return 1 }

//export screencrab_network_version
func screencrab_network_version() *C.char { return cstr("0.2.0") }

//export screencrab_network_create
func screencrab_network_create() unsafe.Pointer { return unsafe.Pointer(state) }

//export screencrab_network_destroy
func screencrab_network_destroy(_ unsafe.Pointer) {}

//export screencrab_network_start
func screencrab_network_start(_ unsafe.Pointer) C.int { return Network_Start() }

//export screencrab_network_stop
func screencrab_network_stop(_ unsafe.Pointer) C.int { return Network_Stop() }

//export screencrab_network_begin_sign_in
func screencrab_network_begin_sign_in(_ unsafe.Pointer) C.int { return Network_Login() }

//export screencrab_network_complete_sign_in
func screencrab_network_complete_sign_in(ctx unsafe.Pointer, token *C.char) C.int { return Network_Refresh() }

//export screencrab_network_status_json
func screencrab_network_status_json(_ unsafe.Pointer) *C.char { return Network_GetStatus() }

//export screencrab_network_last_error_message
func screencrab_network_last_error_message(_ unsafe.Pointer) *C.char { return Network_GetLastError() }

//export screencrab_network_connect_peer
func screencrab_network_connect_peer(_ unsafe.Pointer, peerName *C.char, port C.uint16_t) C.int {
	return Network_ConnectPeer(peerName, port)
}

//export screencrab_network_send
func screencrab_network_send(_ unsafe.Pointer, connID C.uint64_t, data unsafe.Pointer, size C.uint32_t) C.int {
	return Network_Send(connID, data, size)
}

//export screencrab_network_receive
func screencrab_network_receive(_ unsafe.Pointer, connID C.uint64_t, data unsafe.Pointer, size C.uint32_t) C.int {
	return Network_Receive(connID, data, size)
}

//export screencrab_network_disconnect_peer
func screencrab_network_disconnect_peer(_ unsafe.Pointer, connID C.uint64_t) C.int {
	return Network_Disconnect(connID)
}

//export screencrab_network_refresh
func screencrab_network_refresh(_ unsafe.Pointer) C.int { return Network_Refresh() }

func main() {}
