/// Web browser capability matrix.
///
/// §4.7 — Records which WebRTC APIs are supported by each browser engine
/// so the P2P service can apply graceful fallbacks.
library;

enum BrowserEngine { chromium, firefox, safari }

enum SupportLevel { full, partial, none }

class BrowserCapabilities {
  final bool supportsDataChannel;
  final bool supportsPerfectNegotiation;
  final bool supportsTurnTls;
  final SupportLevel perfectNegotiationSupportLevel;

  const BrowserCapabilities({
    required this.supportsDataChannel,
    required this.supportsPerfectNegotiation,
    required this.supportsTurnTls,
    this.perfectNegotiationSupportLevel = SupportLevel.full,
  });
}

class WebCapabilityMatrix {
  const WebCapabilityMatrix._();

  static BrowserCapabilities forBrowser(BrowserEngine engine) =>
      switch (engine) {
        BrowserEngine.chromium => const BrowserCapabilities(
            supportsDataChannel: true,
            supportsPerfectNegotiation: true,
            supportsTurnTls: true,
          ),
        BrowserEngine.firefox => const BrowserCapabilities(
            supportsDataChannel: true,
            supportsPerfectNegotiation: true,
            supportsTurnTls: true,
          ),
        BrowserEngine.safari => const BrowserCapabilities(
            supportsDataChannel: true,
            supportsPerfectNegotiation: false,
            supportsTurnTls: true,
            // Perfect negotiation support in Safari is partial: works but
            // requires a polite-offer workaround for simultaneous-offer cases.
            perfectNegotiationSupportLevel: SupportLevel.partial,
          ),
      };
}
