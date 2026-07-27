package api

type State string

const (
	Offline   State = "offline"
	SignedOut State = "signed_out"
	SigningIn State = "signing_in"
	SignedIn  State = "signed_in"
	Connected State = "connected"
	Retrying  State = "retrying"
	Error     State = "error"
)

type Identity struct {
	AccountEmail string `json:"accountEmail"`
	TailnetName  string `json:"tailnetName"`
	DeviceName   string `json:"deviceName"`
	DeviceID     string `json:"deviceId"`
	TailscaleIP  string `json:"tailscaleIp"`
	SignedIn     bool   `json:"signedIn"`
}

type Peer struct {
	NodeID     string `json:"nodeId"`
	Name       string `json:"name"`
	Address    string `json:"address"`
	Platform   string `json:"platform"`
	Online     bool   `json:"online"`
	LatencyMS  uint32 `json:"latencyMs"`
	Quality    uint32 `json:"quality"`
}

type Status struct {
	State           State     `json:"state"`
	Identity        Identity  `json:"identity"`
	Peers           []Peer    `json:"peers"`
	LastError       string    `json:"lastError"`
	LoginURL        string    `json:"loginUrl"`
	PeerCount       int       `json:"peerCount"`
	Reconnectable   bool      `json:"reconnectable"`
}
