// Package server implements the HTTP/2 and HTTP/3 (QUIC) transport layer.
package server

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"math/big"
	"net"
	"net/http"
	"net/http/httptest"
	"time"

	"github.com/quic-go/quic-go/http3"
)

// Server wraps an HTTP handler and provides both HTTP/2 and HTTP/3 listeners.
type Server struct {
	handler http.Handler
}

// New returns a new Server with the given handler.
func New(h http.Handler) *Server {
	return &Server{handler: h}
}

// StartHTTP2Test starts an HTTP/2 TLS test server on a random local port.
// Returns the "host:port" address, the test server (for its Client()), and a stop function.
func (s *Server) StartHTTP2Test(_ context.Context) (addr string, stop func(), err error) {
	ts := httptest.NewUnstartedServer(s.handler)
	ts.EnableHTTP2 = true
	ts.StartTLS()
	return ts.Listener.Addr().String(), ts.Close, nil
}

// StartHTTP3Test starts an HTTP/3 (QUIC) TLS test server on a random UDP port.
// Returns the "host:port" address and a stop function.
func (s *Server) StartHTTP3Test(_ context.Context) (addr string, stop func(), err error) {
	tlsCfg, err := selfSignedTLS()
	if err != nil {
		return "", nil, err
	}
	udpConn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		return "", nil, err
	}
	h3srv := &http3.Server{
		Handler:   s.handler,
		TLSConfig: tlsCfg,
	}
	errCh := make(chan error, 1)
	go func() {
		errCh <- h3srv.Serve(udpConn)
	}()
	stopFn := func() {
		_ = h3srv.Close()
		_ = udpConn.Close()
	}
	return udpConn.LocalAddr().String(), stopFn, nil
}

// HTTP3Client is a thin wrapper around an http3 Transport.
type HTTP3Client struct {
	rt *http3.Transport
}

// NewHTTP3Client returns an HTTP/3 client that trusts the given TLS config.
func NewHTTP3Client(tlsCfg *tls.Config) (*HTTP3Client, error) {
	rt := &http3.Transport{TLSClientConfig: tlsCfg}
	return &HTTP3Client{rt: rt}, nil
}

// Get issues an HTTP/3 GET to the given URL.
func (c *HTTP3Client) Get(_ context.Context, url string) (*http.Response, error) {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	return c.rt.RoundTrip(req)
}

// Close releases resources held by the round-tripper.
func (c *HTTP3Client) Close() error {
	return c.rt.Close()
}

// selfSignedTLS generates a temporary self-signed certificate for testing.
func selfSignedTLS() (*tls.Config, error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, err
	}
	tmpl := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject:      pkix.Name{CommonName: "test"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(time.Hour),
		IPAddresses:  []net.IP{net.ParseIP("127.0.0.1")},
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		return nil, err
	}
	cert := tls.Certificate{
		Certificate: [][]byte{der},
		PrivateKey:  key,
	}
	return &tls.Config{
		Certificates: []tls.Certificate{cert},
		NextProtos:   []string{"h3"},
	}, nil
}
