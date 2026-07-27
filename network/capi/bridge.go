package main

/*
#include <stdint.h>
*/
import "C"

import (
	"encoding/json"
	"sync"
	"unsafe"

	"screenscrab.network/internal/api"
)

type runtimeState struct {
	mu     sync.Mutex
	status api.Status
}

var state = &runtimeState{
	status: api.Status{
		State:     api.Offline,
		LastError: "embedded runtime not linked",
		Identity: api.Identity{
			DeviceName: "Screenscrab",
			DeviceID:   "pending",
		},
	},
}

//export screencrab_network_api_version
func screencrab_network_api_version() C.uint32_t { return 1 }

//export screencrab_network_version
func screencrab_network_version() *C.char { return C.CString("0.1.0") }

//export screencrab_network_create
func screencrab_network_create() unsafe.Pointer { return unsafe.Pointer(state) }

//export screencrab_network_destroy
func screencrab_network_destroy(_ unsafe.Pointer) {}

//export screencrab_network_start
func screencrab_network_start(_ unsafe.Pointer) C.int { return 0 }

//export screencrab_network_stop
func screencrab_network_stop(_ unsafe.Pointer) C.int { return 0 }

//export screencrab_network_begin_sign_in
func screencrab_network_begin_sign_in(_ unsafe.Pointer) C.int { return 0 }

//export screencrab_network_complete_sign_in
func screencrab_network_complete_sign_in(_ unsafe.Pointer, _ *C.char) C.int { return 0 }

//export screencrab_network_status_json
func screencrab_network_status_json(_ unsafe.Pointer) *C.char {
	state.mu.Lock()
	defer state.mu.Unlock()
	payload, _ := json.Marshal(state.status)
	return C.CString(string(payload))
}

//export screencrab_network_last_error_message
func screencrab_network_last_error_message(_ unsafe.Pointer) *C.char {
	state.mu.Lock()
	defer state.mu.Unlock()
	return C.CString(state.status.LastError)
}

func main() {}
