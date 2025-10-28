Short answer: Dart can be used for parts of a blockchain backend (and is excellent for the client and coordination layers), but it’s not the best choice for implementing the full validator/consensus layer of a production-grade blockchain. I’ll explain why, give practical options, and propose a recommended stack depending on your priorities (speed-to-market, security, maintainability, host incentives).

Why Dart might look attractive
- You already use Dart/Flutter for the client — same language across client + some servers improves developer velocity.  
- Good async model (async/await, Futures, Streams) and isolates for concurrency.  
- Decent crypto + networking libraries exist (cryptography, pointycastle, grpc-dart, shelf).  
- Fast for many web/back-end tasks (JIT/AOT on Dart VM and native AOT).

Why Dart is a poor fit for the full blockchain backend (validator/consensus) in production
- Ecosystem maturity: Blockchain infra relies on battle-tested libraries (consensus, BFT, low-level crypto, peer-to-peer networking, formal tooling). Rust/Go have far broader, production-proven ecosystems (Substrate, Tendermint/Cosmos SDK, libp2p, etc.).  
- Performance & determinism: Consensus validators need predictable, high-throughput, low-latency execution and low GC/pause behaviour. Rust/Go are better suited for sustained, CPU-bound workloads and deterministic memory behavior.  
- Concurrency model: Dart isolates work, but passing large state between isolates is less ergonomic and can be slower than native threads/async models in Go/Rust.  
- Long-term security & auditability: Validators must be auditable and verifiable. Libraries and language features in Rust/Go are more commonly used and audited in blockchain projects.  
- Community & tooling: Debuggers, profilers, formal verification, and a community of node implementers — stronger in Rust/Go.

Where Dart is a good fit
- Client (Flutter) — wallet, signing UI, local state, peer discovery UI: excellent.  
- Gateway / API layer / Matchmaking / Leaderboards / Payment gateway / Light client API: good fit (shelf, jaguar, grpc-dart, cloud run, serverless).  
- Transaction creation & signing tools on the client.  
- Prototyping and simulation — quick to iterate in Dart.

Recommended practical approaches (pick one based on goals)

1) Production-grade blockchain quickly and safely (Recommended)
- Consensus, validators, chain runtime: Rust (Substrate) or Go (Cosmos SDK / Tendermint). Rationale: leverages mature frameworks, secure, scalable, many examples and validators.  
- Matchmaking, account services, bridging, UI APIs, payment processors: Dart/Node/Go (your choice).  
- Client (Flutter): Dart (obvious).  
- Bridge: write a light service in Rust/Go to accept on-chain proofs and mint/lock tokens in your internal ledger.

2) Hybrid (fast to build, future bridging)
- Use an internal ledger (DB-backed, crypto-signed transactions) for day-one economy and run a permissioned validator set implemented in Go/Rust.  
- Keep Dart for the API/gateway, wallet signing, and admin tools. When ready, bridge to a public chain (Polygon/Solana) or a private Substrate parachain.  
- Advantages: low infra cost, you avoid reinventing a full consensus, you can later “bridge” or migrate.

3) All-in-Dart prototype / research network (if you want to experiment)
- Build a minimal proof-of-authority (PoA) or delegated-PoS prototype in Dart. Useful to validate tokenomics, witness consensus and UX.  
- Use isolates for parallel tasks, grpc-dart for RPC, cryptography package for key ops.  
- Strong caveat: do not run this prototype as the economic mainnet. Use it for testnets only.

Concrete mapping of components → recommended language
- Client wallets / signing / Flutter UI: Dart (Flutter).  
- Lightweight API / matchmaker / leaderboards / transaction relayer: Dart OK.  
- Validators / Consensus / Block proposer / P2P gossip: Rust or Go (strongly recommended).  
- Storage / explorer / analytics: PostgreSQL + Node/Go microservices / Rust for heavy queries.  
- Bridges to public chains: implement bridge logic in Rust/Go (or build smart contracts in Solidity + off-chain relayers).

Interoperability options
- RPC (gRPC/HTTP) between Dart services and Rust/Go validators. grpc-dart plays well with gRPC in other languages.  
- FFI: For performance-critical crypto primitives you can call Rust from Dart via dart:ffi (but maintainability is harder).  
- Message broker: Use Kafka/Redis/RabbitMQ to decouple services (Dart can produce/consume via packages).

Libraries & tooling pointers
- Dart crypto: package:cryptography (ECDSA/Ed25519), pointycastle (older), package:crypto for hashes.  
- Networking: grpc-dart, shelf, shelf_web_socket, websocket.  
- Rust blockchain frameworks: Substrate (Polkadot ecosystem) — best for building custom chains; Parity tooling is extensive.  
- Go frameworks: Cosmos SDK + Tendermint — excellent for PoS chains with BFT consensus.  
- P2P: libp2p (Rust/Go implementations; JS has a version). Reimplementing P2P in Dart is risky.

Security & auditing
- Consensus code must be small, well-tested, and audited. Prefer languages with strong static guarantees (Rust) and formal verification options.  
- Use ECDSA/Ed25519 for signing; never send private keys to servers.  
- Build extensive unit, integration, and fuzz tests. Consider formal verification for critical modules.

Practical next steps I can help with
- If you want to keep Dart-first: I can scaffold a secure, well-instrumented prototype in Dart for:
  - transaction format + signing + merkle root generation,
  - a simple PoA validator simulator (testnet only),
  - wallet UI + signing in Flutter.
- If you want production: I can propose a concrete architecture using Substrate or Tendermint + a detailed migration/bridge plan and cost estimate.
- Or I can create a decision matrix comparing Substrate vs Cosmos vs building in Dart for your specific constraints (team skill, timeline, budget).

Which direction do you prefer?
- Prototype-only in Dart (fast experiment), or  
- Hybrid: Dart client + Rust/Go validators (recommended for production), or  
- Full production stack on Substrate/Cosmos (lowest long-term risk)?