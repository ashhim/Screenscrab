package main

/*
#include <stdint.h>
*/
import "C"

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"strings"
	"sync"
	"time"
	"unsafe"

	"screenscrab.network/internal/api"

	"tailscale.com/client/local"
	"tailscale.com/ipn"
	"tailscale.com/tsnet"
)

type connection struct {
	conn net.Conn
}

type runtimeState struct {
	mu          sync.Mutex
	started      bool
	server       *tsnet.Server
	localClient  *local.Client
	status       api.Status
	lastError    string
	identityJSON string
	conns        map[uint64]*connection
	nextConnID   uint64
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
		Reconnectable:  true,
	},
	conns: map[uint64]*connection{},
}

func cString(s string) *C.char { return C.CString(s) }

func copyCString(s string) *C.char { return cString(strings.TrimRight(s, "\x00")) }

func (r *runtimeState) refreshStatusLocked(ctx context.Context) {
	if r.server == nil || r.localClient == nil {
		return
	}
	st, err := r.localClient.Status(ctx)
	if err != nil || st == nil {
		r.lastError = fmt.Sprintf("status failed: %v", err)
		r.status.State = api.Error
		r.status.LastError = r.lastError
		return
	}

	r.status.State = api.SignedIn
	r.status.Identity = api.Identity{
		SignedIn:     true,
		DeviceName:   st.Self.DNSName,
		DeviceID:     fmt.Sprint(st.Self.ID),
		TailscaleIP:  st.Self.TailscaleIPs[0].String(),
		AccountEmail: st.User[st.Self.UserID].LoginName,
		TailnetName:  st.CurrentTailnet.Name,
	}
	if st.Self.Online {
		r.status.State = api.Connected
	}
	peers := make([]api.Peer, 0, len(st.Peer))
	for _, peer := range st.Peer {
		peers = append(peers, api.Peer{
			NodeID:    fmt.Sprint(peer.ID),
			Name:      peer.DNSName,
			Address:   peer.TailscaleIPs[0].String(),
			Platform:  peer.OS,
			Online:    peer.Online,
			LatencyMS: uint32(peer.LastSeen.Within(time.Minute).Milliseconds()),
			Quality:   uint32(peer.PingMS),
		})
	}
	r.status.Peers = peers
	r.status.PeerCount = len(peers)
	r.status.LastError = r.lastError
	r.status.Reconnectable = true
}

func (r *runtimeState) startLocked() error {
	if r.started {
		return nil
	}
	srv := &tsnet.Server{
		Hostname: "screenscrab",
	}
	if key := os.Getenv("SCREENSCRAB_TS_AUTHKEY"); key != "" {
		srv.AuthKey = key
	}
	lc, err := srv.LocalClient()
	if err != nil {
		return err
	}
	r.server = srv
	r.localClient = lc
	r.started = true
	r.status.State = api.SigningIn
	r.status.LastError = ""
	r.status.LoginURL = ""
	return nil
}

func (r *runtimeState) stopLocked() {
	if r.server != nil {
		_ = r.server.Close()
	}
	r.server = nil
	r.localClient = nil
	r.started = false
	r.status = api.Status{
		State: api.Offline,
		Identity: api.Identity{
			DeviceName: "Screenscrab",
			DeviceID:   "pending",
		},
		Peers:         []api.Peer{},
		LastError:     "network stopped",
		Reconnectable:  true,
	}
	for _, conn := range r.conns {
		if conn.conn != nil {
			_ = conn.conn.Close()
		}
	}
	r.conns = map[uint64]*connection{}
	r.nextConnID = 0
}

//export screencrab_network_api_version
func screencrab_network_api_version() C.uint32_t { return 1 }

//export screencrab_network_version
func screencrab_network_version() *C.char { return cString("0.1.0") }

//export screencrab_network_create
func screencrab_network_create() unsafe.Pointer { return unsafe.Pointer(state) }

//export screencrab_network_destroy
func screencrab_network_destroy(_ unsafe.Pointer) {}

//export screencrab_network_start
func screencrab_network_start(_ unsafe.Pointer) C.int {
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

//export screencrab_network_stop
func screencrab_network_stop(_ unsafe.Pointer) C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	state.stopLocked()
	return 0
}

//export screencrab_network_begin_sign_in
func screencrab_network_begin_sign_in(_ unsafe.Pointer) C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	if err := state.startLocked(); err != nil {
		state.lastError = err.Error()
		state.status.State = api.Error
		state.status.LastError = state.lastError
		return -1
	}
	// tsnet prints an auth URL to the log sink on first login; the actual
	// interactive completion is handled by the embedded Tailscale flow.
	state.status.State = api.SigningIn
	return 0
}

//export screencrab_network_complete_sign_in
func screencrab_network_complete_sign_in(_ unsafe.Pointer, _ *C.char) C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	state.refreshStatusLocked(ctx)
	return 0
}

//export screencrab_network_status_json
func screencrab_network_status_json(_ unsafe.Pointer) *C.char {
	state.mu.Lock()
	defer state.mu.Unlock()
	payload, _ := json.Marshal(state.status)
	return cString(string(payload))
}

//export screencrab_network_last_error_message
func screencrab_network_last_error_message(_ unsafe.Pointer) *C.char {
	state.mu.Lock()
	defer state.mu.Unlock()
	return cString(state.lastError)
}

//export screencrab_network_connect_peer
func screencrab_network_connect_peer(_ unsafe.Pointer, peerName *C.char, port C.uint16_t) C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	if state.localClient == nil {
		return -1
	}
	name := C.GoString(peerName)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := state.localClient.DialTCP(ctx, name, uint16(port))
	if err != nil {
		state.lastError = err.Error()
		state.status.LastError = state.lastError
		state.status.State = api.Error
		return -1
	}
	state.nextConnID++
	state.conns[state.nextConnID] = &connection{conn: conn}
	state.status.State = api.Connected
	return C.int(state.nextConnID)
}

//export screencrab_network_send
func screencrab_network_send(_ unsafe.Pointer, connID C.uint64_t, data unsafe.Pointer, size C.uint32_t) C.int {
	state.mu.Lock()
	c := state.conns[uint64(connID)]
	state.mu.Unlock()
	if c == nil || c.conn == nil || data == nil || size == 0 {
		return -1
	}
	buf := unsafe.Slice((*byte)(data), int(size))
	n, err := c.conn.Write(buf)
	if err != nil {
		return -1
	}
	return C.int(n)
}

//export screencrab_network_receive
func screencrab_network_receive(_ unsafe.Pointer, connID C.uint64_t, data unsafe.Pointer, size C.uint32_t) C.int {
	state.mu.Lock()
	c := state.conns[uint64(connID)]
	state.mu.Unlock()
	if c == nil || c.conn == nil || data == nil || size == 0 {
		return -1
	}
	buf := unsafe.Slice((*byte)(data), int(size))
	n, err := c.conn.Read(buf)
	if err != nil && !errors.Is(err, net.ErrClosed) {
		return -1
	}
	return C.int(n)
}

//export screencrab_network_disconnect_peer
func screencrab_network_disconnect_peer(_ unsafe.Pointer, connID C.uint64_t) C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	c := state.conns[uint64(connID)]
	if c == nil || c.conn == nil {
		return -1
	}
	_ = c.conn.Close()
	delete(state.conns, uint64(connID))
	return 0
}

//export screencrab_network_refresh
func screencrab_network_refresh(_ unsafe.Pointer) C.int {
	state.mu.Lock()
	defer state.mu.Unlock()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	state.refreshStatusLocked(ctx)
	return 0
}

func main() {}
