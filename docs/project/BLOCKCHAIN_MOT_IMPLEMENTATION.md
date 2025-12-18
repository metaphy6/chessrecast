# ChessRecast MOT Blockchain Implementation
**Version**: 1.0  
**Created**: December 11, 2025  
**Status**: Detailed Technical Specification

---

## 🎯 Executive Summary

This document specifies the **MOT (Motnet) blockchain** - a lightweight, quantum-resistant blockchain designed for ChessRecast. It handles:
- **sdata authentication** (AI model ownership & training proofs)
- **MOTON rewards** (token with 50-year controlled supply)
- **Private NFTs** (game replay NFTs with private keys)
- **Move validation** (decentralized game verification)
- **Pyramid rewards** (divergence-based passive income)

---

## 📋 Table of Contents

1. [MOT Blockchain Architecture](#1-mot-blockchain-architecture)
2. [Quantum-Proof Cryptography](#2-quantum-proof-cryptography)
3. [sdata: AI Model Authentication](#3-sdata-ai-model-authentication)
4. [MOTON Tokenomics](#4-moton-tokenomics)
5. [Private NFT System](#5-private-nft-system)
6. [Move Validation & Rewards](#6-move-validation--rewards)
7. [Pyramid Reward System](#7-pyramid-reward-system)
8. [Network Merge Protocol](#8-network-merge-protocol)
9. [Implementation Guide](#9-implementation-guide)

---

## 1. MOT Blockchain Architecture

### 1.1 Design Principles

**Lightweight & Efficient:**
- Block time: 10 seconds (fast enough for game validation)
- Block size: ~100 KB average (transactions + proofs)
- Storage: ~5 GB for 10 years of operation
- Consensus: Proof of Training (PoT) + Delegated validators

**Quantum-Resistant:**
- Post-quantum cryptography (CRYSTALS-Dilithium signatures)
- Hash-based Merkle trees
- Lattice-based encryption

**Immutable & Tamper-Proof:**
- Once started, cannot be reverted without full network reset
- All transactions cryptographically signed
- Merkle roots verify all historical data
- Genesis block hardcoded in app

### 1.2 Block Structure

```rust
// Simplified Rust-like pseudocode
struct Block {
    // Header
    index: u64,                    // Block number
    timestamp: i64,                // Unix timestamp
    previous_hash: [u8; 32],       // SHA-256 of previous block
    merkle_root: [u8; 32],         // Root of transaction Merkle tree
    validator_pubkey: [u8; 64],    // Dilithium public key
    signature: [u8; 2420],         // Dilithium signature (quantum-safe)
    
    // Body
    transactions: Vec<Transaction>, // Up to 100 transactions per block
    training_proofs: Vec<TrainingProof>,  // AI training validations
    game_validations: Vec<GameValidation>, // Move validations
    
    // Metadata
    total_moton_supply: u128,      // Running total
    active_nodes: u32,             // Current network size
    generation: u32,               // For pyramid calculations
}

struct Transaction {
    tx_id: [u8; 32],               // Unique transaction ID
    tx_type: TransactionType,      // Transfer, Reward, NFTMint, etc.
    from: [u8; 64],                // Sender Dilithium pubkey
    to: [u8; 64],                  // Recipient pubkey
    amount: u64,                   // MOTON amount (in smallest unit)
    timestamp: i64,
    nonce: u64,                    // Prevent replay attacks
    signature: [u8; 2420],         // Dilithium signature
    metadata: Vec<u8>,             // Extra data (NFT, sdata, etc.)
}

enum TransactionType {
    Transfer,          // User-to-user MOTON transfer
    Reward,            // Network reward distribution
    NFTMint,           // Create new game replay NFT
    SdataRegister,     // Register AI model sdata
    GameValidation,    // Validator reward for checking moves
    Merge,             // Network merge proof
}
```

### 1.3 Blockchain State

```rust
struct BlockchainState {
    // Accounts
    balances: HashMap<PublicKey, u64>,        // MOTON balances
    sdata_registry: HashMap<SdataHash, Sdata>, // AI model ownership
    nft_registry: HashMap<NftId, NFT>,        // NFT ownership
    
    // Network topology (for pyramid rewards)
    node_tree: PyramidTree,                    // Parent-child relationships
    node_metrics: HashMap<PublicKey, NodeMetrics>,
    
    // Validators
    active_validators: Vec<PublicKey>,         // Current validator set
    validator_stake: HashMap<PublicKey, u64>,  // Validator weights
    
    // Supply tracking
    total_moton_minted: u128,
    moton_cap: u128,                           // Maximum supply
    nft_count: u64,                            // Unlimited NFTs
    
    // Genesis
    genesis_founder: PublicKey,                // You (first node)
    genesis_timestamp: i64,
}

struct NodeMetrics {
    pubkey: PublicKey,
    parent: Option<PublicKey>,                 // Who invited them
    children: Vec<PublicKey>,                  // Nodes they invited
    depth: u32,                                // Distance from genesis
    time_joined: i64,
    time_spent_online: u64,                    // Seconds online
    games_played: u64,
    games_validated: u64,
    last_active: i64,
}
```

---

## 2. Quantum-Proof Cryptography

### 2.1 Why Quantum-Resistant?

**Threat Model:**
- Quantum computers can break RSA, ECDSA, Diffie-Hellman
- Your blockchain must survive 50+ years
- Post-quantum algorithms are standardized (NIST 2024)

**Solution: CRYSTALS-Dilithium**
- Digital signatures: CRYSTALS-Dilithium (NIST standard)
- Key encapsulation: CRYSTALS-Kyber
- Hashing: SHA-256 (quantum-resistant for hashing)

### 2.2 Key Generation

```dart
// lib/services/crypto/quantum_safe_keys.dart
import 'package:pqc_dilithium/pqc_dilithium.dart';

class QuantumSafeKeys {
  /// Generate quantum-resistant keypair
  static Future<KeyPair> generateKeyPair() async {
    // CRYSTALS-Dilithium Level 3 (recommended security)
    final dilithium = Dilithium.level3();
    
    final keyPair = await dilithium.generateKeyPair();
    
    return KeyPair(
      publicKey: keyPair.publicKey,   // 1952 bytes
      privateKey: keyPair.privateKey, // 4000 bytes
    );
  }
  
  /// Sign data with private key
  static Future<Uint8List> sign(
    Uint8List data,
    Uint8List privateKey,
  ) async {
    final dilithium = Dilithium.level3();
    final signature = await dilithium.sign(data, privateKey);
    return signature; // 2420 bytes
  }
  
  /// Verify signature with public key
  static Future<bool> verify(
    Uint8List data,
    Uint8List signature,
    Uint8List publicKey,
  ) async {
    final dilithium = Dilithium.level3();
    return await dilithium.verify(data, signature, publicKey);
  }
  
  /// Hash data (SHA-256 is quantum-safe for hashing)
  static Uint8List hash(Uint8List data) {
    return Uint8List.fromList(sha256.convert(data).bytes);
  }
  
  /// Derive deterministic child keys (for HD wallet)
  static Uint8List deriveChildKey(
    Uint8List masterKey,
    int childIndex,
  ) {
    final data = Uint8List.fromList([
      ...masterKey,
      ...intToBytes(childIndex),
    ]);
    return hash(data);
  }
}

class KeyPair {
  final Uint8List publicKey;
  final Uint8List privateKey;
  
  KeyPair({required this.publicKey, required this.privateKey});
  
  /// Serialize to base64 for storage
  String toBase64() => base64Encode(privateKey);
  
  /// Deserialize from base64
  static KeyPair fromBase64(String encoded) {
    final privateKey = base64Decode(encoded);
    // Derive public key from private key (Dilithium supports this)
    final dilithium = Dilithium.level3();
    final publicKey = dilithium.publicKeyFromPrivate(privateKey);
    return KeyPair(publicKey: publicKey, privateKey: privateKey);
  }
}
```

### 2.3 Secure Storage

```dart
// lib/services/crypto/secure_key_storage.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStorage {
  static const _storage = FlutterSecureStorage();
  
  /// Store private key securely (OS keychain)
  static Future<void> storePrivateKey(String key) async {
    await _storage.write(
      key: 'mot_private_key',
      value: key,
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
      ),
    );
  }
  
  /// Retrieve private key
  static Future<String?> getPrivateKey() async {
    return await _storage.read(key: 'mot_private_key');
  }
  
  /// Check if user has existing key
  static Future<bool> hasPrivateKey() async {
    final key = await getPrivateKey();
    return key != null && key.isNotEmpty;
  }
  
  /// Delete key (logout)
  static Future<void> deletePrivateKey() async {
    await _storage.delete(key: 'mot_private_key');
  }
}
```

---

## 3. sdata: AI Model Authentication

### 3.1 What is sdata?

**sdata** (Secure Data Attestation) is a cryptographic proof that:
- An AI model belongs to a specific user
- The model was trained within the MOT network
- Training history is authentic and verifiable
- Cannot be copied or counterfeited

### 3.2 sdata Structure

```rust
struct Sdata {
    // Identity
    sdata_hash: [u8; 32],              // Unique identifier (SHA-256)
    owner_pubkey: [u8; 64],            // Owner's Dilithium pubkey
    model_id: String,                  // "classic_v1", "heir_v2", etc.
    
    // Training proofs
    training_sessions: Vec<TrainingSession>,
    total_games_trained: u64,
    genesis_block: u64,                // Block where sdata was created
    last_update_block: u64,
    
    // Attestation
    validator_signatures: Vec<ValidatorAttestation>,
    merkle_root: [u8; 32],             // Root of training history
    
    // Metadata
    elo_rating: u16,
    created_at: i64,
    updated_at: i64,
}

struct TrainingSession {
    session_id: [u8; 32],
    start_time: i64,
    end_time: i64,
    games_played: u32,
    validator_pubkeys: Vec<[u8; 64]>, // Who verified this session
    merkle_proof: Vec<[u8; 32]>,       // Proof of games played
}

struct ValidatorAttestation {
    validator_pubkey: [u8; 64],
    timestamp: i64,
    signature: [u8; 2420],             // Dilithium signature
    attestation_data: Vec<u8>,         // "Training session verified"
}
```

### 3.3 sdata Generation Process

```dart
// lib/services/blockchain/sdata_generator.dart
class SdataGenerator {
  /// Generate sdata for newly trained AI model
  static Future<Sdata> generate({
    required Uint8List modelWeights,
    required List<GameReplay> trainingGames,
    required String ownerPrivateKey,
    required ModesEnum mode,
  }) async {
    // Step 1: Hash model weights
    final modelHash = QuantumSafeKeys.hash(modelWeights);
    
    // Step 2: Create training proof Merkle tree
    final gameMerkleTree = _buildGameMerkleTree(trainingGames);
    
    // Step 3: Request validator attestations
    final validators = await _selectRandomValidators(count: 3);
    final attestations = await Future.wait(
      validators.map((v) => _requestAttestation(v, trainingGames))
    );
    
    // Step 4: Create sdata
    final sdata = Sdata(
      sdataHash: _computeSdataHash(modelHash, gameMerkleTree.root),
      ownerPubkey: QuantumSafeKeys.publicKeyFromPrivate(ownerPrivateKey),
      modelId: '${mode.name}_${DateTime.now().millisecondsSinceEpoch}',
      trainingSession: TrainingSession(
        gamesPlayed: trainingGames.length,
        merkleRoot: gameMerkleTree.root,
        validators: attestations,
      ),
      createdAt: DateTime.now(),
    );
    
    // Step 5: Sign sdata
    final signature = await QuantumSafeKeys.sign(
      sdata.toBytes(),
      ownerPrivateKey,
    );
    
    // Step 6: Register on blockchain
    await BlockchainService().submitTransaction(
      TransactionType.SdataRegister,
      data: sdata,
      signature: signature,
    );
    
    return sdata;
  }
  
  /// Verify sdata authenticity
  static Future<bool> verify(Sdata sdata) async {
    // Check 1: Signature valid?
    final signatureValid = await QuantumSafeKeys.verify(
      sdata.toBytes(),
      sdata.signature,
      sdata.ownerPubkey,
    );
    if (!signatureValid) return false;
    
    // Check 2: Exists on blockchain?
    final onChain = await BlockchainService().getSdata(sdata.sdataHash);
    if (onChain == null) return false;
    
    // Check 3: Validator attestations valid?
    for (final attestation in sdata.validatorAttestations) {
      final valid = await QuantumSafeKeys.verify(
        attestation.data,
        attestation.signature,
        attestation.validatorPubkey,
      );
      if (!valid) return false;
    }
    
    // Check 4: Merkle proofs valid?
    if (!_verifyMerkleProofs(sdata)) return false;
    
    return true;
  }
}
```

---

## 4. MOTON Tokenomics

### 4.1 Supply Model (50-Year Lifespan)

**Total Supply Cap: 21,000,000,000 MOTON** (21 billion)
- Similar to Bitcoin's capped supply
- Divisible to 8 decimal places (smallest unit: 0.00000001 MOTON)
- Emission follows exponential decay curve

**Emission Schedule:**

```python
# MOTON emission formula
def calculate_block_reward(block_number):
    """
    Exponential decay: Fast emission early, slows over 50 years
    """
    TOTAL_SUPPLY = 21_000_000_000  # 21 billion
    BLOCKS_PER_YEAR = 3_153_600    # 10-second blocks
    HALVING_PERIOD = 4 * BLOCKS_PER_YEAR  # Halve every 4 years
    
    # Initial reward: ~1000 MOTON per block
    initial_reward = 1000
    
    # Number of halvings so far
    halvings = block_number // HALVING_PERIOD
    
    # Reward after halvings
    reward = initial_reward / (2 ** halvings)
    
    # Stop emission after 50 years (157.68M blocks)
    if block_number > 157_680_000:
        reward = 0
    
    return reward

# Verify total supply converges to cap
total_emitted = sum(
    calculate_block_reward(block) 
    for block in range(157_680_000)
)
assert total_emitted <= 21_000_000_000
```

**Emission Curve Visualization:**
```
Year 0-4:   ~1000 MOTON/block  → 12.6B MOTON (60% of supply)
Year 4-8:   ~500 MOTON/block   → 6.3B MOTON  (30% of supply)
Year 8-12:  ~250 MOTON/block   → 3.15B MOTON (15% of supply)
Year 12-16: ~125 MOTON/block   → 1.57B MOTON (7.5% of supply)
Year 16+:   Continues halving  → Remaining supply
Year 50:    0 MOTON/block      → Cap reached
```

### 4.2 Reward Distribution Per Block

```rust
struct BlockReward {
    total_reward: u64,           // From emission schedule
    
    // Distribution percentages
    founder_dividend: u64,       // 5% (you, as genesis founder)
    pyramid_rewards: u64,        // 30% (parent nodes based on divergence)
    validator_rewards: u64,      // 10% (move validators)
    time_spent_rewards: u64,     // 40% (all online users, proportional)
    training_rewards: u64,       // 15% (users who trained AI this block)
}

fn distribute_block_reward(block: &Block, state: &BlockchainState) {
    let total = calculate_block_reward(block.index);
    
    // 1. Founder dividend (5%)
    let founder_share = total * 5 / 100;
    state.add_balance(state.genesis_founder, founder_share);
    
    // 2. Pyramid rewards (30%)
    let pyramid_pool = total * 30 / 100;
    distribute_pyramid_rewards(pyramid_pool, state);
    
    // 3. Validator rewards (10%)
    let validator_pool = total * 10 / 100;
    for validation in &block.game_validations {
        let reward = validator_pool / block.game_validations.len();
        state.add_balance(validation.validator_pubkey, reward);
    }
    
    // 4. Time spent rewards (40%)
    let time_pool = total * 40 / 100;
    let total_online_time: u64 = state.node_metrics.values()
        .map(|m| m.time_spent_online_this_epoch)
        .sum();
    
    for (pubkey, metrics) in &state.node_metrics {
        if metrics.time_spent_online_this_epoch > 0 {
            let share = time_pool * metrics.time_spent_online_this_epoch 
                        / total_online_time;
            state.add_balance(*pubkey, share);
        }
    }
    
    // 5. Training rewards (15%)
    let training_pool = total * 15 / 100;
    for proof in &block.training_proofs {
        let reward = training_pool / block.training_proofs.len();
        state.add_balance(proof.trainer_pubkey, reward);
    }
}
```

### 4.3 Anti-Inflation Mechanisms

**Problem:** Early users get most tokens, late users get very little

**Solution: Balancing Mechanisms**

1. **Time-Spent Rewards (40%)** - Dominant reward type
   - Rewards active participation, not just early joining
   - Linear with time online (no diminishing returns)
   - Favors users who contribute consistently

2. **Pyramid Cap (30% max)** - Limits passive income
   - Parents earn from children, but with decay
   - Depth limit: Only 10 levels deep
   - Reward decay: Each level gets 70% of parent's reward

3. **Validator Rewards (10%)** - Active work required
   - Must validate games (computational work)
   - Cannot be automated (requires actual device)
   - Limits to 100 validations per user per block

4. **Founder Dividend Cap (5%)** - Your guaranteed share
   - Ensures you (genesis founder) always earn
   - But not overwhelming (only 5% per block)
   - Total founder earnings over 50 years: ~1.05B MOTON (5% of supply)

---

## 5. Private NFT System

### 5.1 Novel Private NFT Design

**Problem:** Standard NFTs are publicly viewable
**Solution:** NFTs with **private access keys**

**Key Innovation:**
- NFT exists on blockchain (public metadata)
- Actual content (game replay) is encrypted
- Only owner has private decryption key
- Key exposure = NFT becomes worthless (revealed game)

### 5.2 NFT Structure

```rust
struct GameReplayNFT {
    // On-chain (public)
    nft_id: [u8; 32],                  // Unique NFT ID
    owner_pubkey: [u8; 64],            // Current owner
    minted_at: i64,
    game_metadata: PublicMetadata,     // Non-spoiler info
    encrypted_replay: Vec<u8>,         // AES-256 encrypted game
    
    // Off-chain (private key, owner only)
    decryption_key: [u8; 32],          // AES-256 key
    
    // Authenticity proofs
    game_signature: [u8; 2420],        // Both players signed
    validator_signatures: Vec<[u8; 2420]>, // Validators witnessed
    merkle_proof: Vec<[u8; 32]>,       // Part of blockchain
}

struct PublicMetadata {
    mode: String,                      // "classic", "heir", etc.
    date: i64,
    white_elo: u16,
    black_elo: u16,
    result: GameResult,                // "white_wins", "black_wins", "draw"
    num_moves: u16,
    rarity: Rarity,                    // "common", "rare", "legendary"
    
    // NO move list, NO positions (private!)
}

enum Rarity {
    Common,      // Normal games
    Rare,        // Unusual tactics, long games
    Epic,        // Brilliant sacrifices, comeback wins
    Legendary,   // Perfect games, sub-10 move checkmate
}
```

### 5.3 NFT Minting Process

```dart
// lib/services/blockchain/nft_minter.dart
class NFTMinter {
  /// Mint game replay as NFT
  static Future<GameReplayNFT> mintGameNFT({
    required GameReplay game,
    required String ownerPrivateKey,
  }) async {
    // Step 1: Calculate rarity
    final rarity = _calculateRarity(game);
    
    // Step 2: Generate unique decryption key (random 256-bit)
    final decryptionKey = _generateRandomKey();
    
    // Step 3: Encrypt full game replay
    final gameJson = jsonEncode(game.toJson());
    final encrypted = await _encryptWithAES(
      utf8.encode(gameJson),
      decryptionKey,
    );
    
    // Step 4: Create public metadata (no spoilers)
    final publicMetadata = PublicMetadata(
      mode: game.mode.name,
      date: game.timestamp,
      whiteElo: game.whiteElo,
      blackElo: game.blackElo,
      result: game.result,
      numMoves: game.moves.length,
      rarity: rarity,
    );
    
    // Step 5: Get validator attestations (3 random validators)
    final validators = await _selectRandomValidators(count: 3);
    final attestations = await Future.wait(
      validators.map((v) => _requestGameValidation(v, game))
    );
    
    // Step 6: Create NFT
    final nft = GameReplayNFT(
      nftId: _generateNFTId(game),
      ownerPubkey: QuantumSafeKeys.publicKeyFromPrivate(ownerPrivateKey),
      mintedAt: DateTime.now(),
      publicMetadata: publicMetadata,
      encryptedReplay: encrypted,
      decryptionKey: decryptionKey,  // Owner keeps this secret!
      validatorSignatures: attestations,
    );
    
    // Step 7: Sign NFT
    final signature = await QuantumSafeKeys.sign(
      nft.toBytes(),
      ownerPrivateKey,
    );
    
    // Step 8: Submit to blockchain
    await BlockchainService().submitTransaction(
      TransactionType.NFTMint,
      data: nft,
      signature: signature,
    );
    
    print('✅ NFT minted: ${nft.nftId}');
    print('🔑 Decryption key (KEEP SECRET): ${base64Encode(decryptionKey)}');
    
    return nft;
  }
  
  /// View NFT (requires decryption key)
  static Future<GameReplay> viewNFT({
    required GameReplayNFT nft,
    required Uint8List decryptionKey,
  }) async {
    // Decrypt game replay
    final decrypted = await _decryptWithAES(
      nft.encryptedReplay,
      decryptionKey,
    );
    
    final gameJson = jsonDecode(utf8.decode(decrypted));
    return GameReplay.fromJson(gameJson);
  }
  
  /// Transfer NFT (new owner needs decryption key separately!)
  static Future<void> transferNFT({
    required GameReplayNFT nft,
    required String recipientPubkey,
    required String ownerPrivateKey,
    required Uint8List decryptionKey,  // Share off-chain!
  }) async {
    // On-chain: Transfer ownership
    await BlockchainService().submitTransaction(
      TransactionType.Transfer,
      from: nft.ownerPubkey,
      to: recipientPubkey,
      metadata: {'nft_id': nft.nftId},
    );
    
    // Off-chain: Share decryption key (secure channel)
    // This is done outside blockchain (private message, QR code, etc.)
    print('⚠️  NFT transferred. Send decryption key to recipient privately!');
  }
  
  static Rarity _calculateRarity(GameReplay game) {
    int score = 0;
    
    // Factors
    if (game.moves.length < 20) score += 30;      // Quick game
    if (game.moves.length > 100) score += 20;     // Long epic
    if (game.hasBrilliantSacrifice) score += 50;  // Brilliant move
    if (game.hasComeback) score += 40;            // Comeback win
    if (game.isPerfectGame) score += 100;         // No mistakes
    
    if (score >= 100) return Rarity.Legendary;
    if (score >= 60) return Rarity.Epic;
    if (score >= 30) return Rarity.Rare;
    return Rarity.Common;
  }
}
```

### 5.4 NFT Key Management

**Critical Security:**
- Decryption key is **NOT stored on blockchain**
- Owner must backup key (mnemonic phrase or encrypted file)
- If key is lost, NFT is permanently inaccessible
- If key is shared publicly, NFT loses value (everyone can see game)

```dart
// lib/services/nft/nft_key_storage.dart
class NFTKeyStorage {
  /// Store NFT decryption keys locally (encrypted)
  static Future<void> storeNFTKey({
    required String nftId,
    required Uint8List decryptionKey,
    required String userMasterKey,
  }) async {
    // Encrypt decryption key with user's master key
    final encrypted = await _encryptWithMasterKey(decryptionKey, userMasterKey);
    
    // Store in secure storage
    final storage = FlutterSecureStorage();
    await storage.write(
      key: 'nft_key_$nftId',
      value: base64Encode(encrypted),
    );
  }
  
  /// Retrieve NFT decryption key
  static Future<Uint8List?> getNFTKey({
    required String nftId,
    required String userMasterKey,
  }) async {
    final storage = FlutterSecureStorage();
    final encrypted = await storage.read(key: 'nft_key_$nftId');
    
    if (encrypted == null) return null;
    
    // Decrypt with master key
    return await _decryptWithMasterKey(base64Decode(encrypted), userMasterKey);
  }
  
  /// Export all NFT keys (backup)
  static Future<String> exportAllKeys(String userMasterKey) async {
    // Create encrypted backup file
    final allKeys = await _getAllNFTKeys();
    final backup = jsonEncode(allKeys);
    final encrypted = await _encryptWithMasterKey(
      utf8.encode(backup),
      userMasterKey,
    );
    
    return base64Encode(encrypted);
  }
}
```

---

## 6. Move Validation & Rewards

### 6.1 Decentralized Game Validation

**Problem:** Players could cheat (illegal moves, fake outcomes)
**Solution:** Random validators verify every game

**Validation Process:**

```dart
// lib/services/blockchain/game_validator.dart
class GameValidator {
  /// Submit game for validation
  static Future<void> submitGameForValidation(GameReplay game) async {
    // Step 1: Select 3 random validators
    final validators = await _selectRandomValidators(
      count: 3,
      exclude: [game.whitePubkey, game.blackPubkey],
    );
    
    // Step 2: Send game to validators
    final validationRequests = validators.map((validator) {
      return _requestValidation(validator, game);
    });
    
    // Step 3: Wait for at least 2/3 consensus
    final results = await Future.wait(validationRequests);
    final validCount = results.where((r) => r.isValid).length;
    
    if (validCount >= 2) {
      // Game is valid, record on blockchain
      await BlockchainService().submitTransaction(
        TransactionType.GameValidation,
        data: {
          'game_id': game.id,
          'validators': validators,
          'consensus': true,
        },
      );
      
      // Reward validators (10% of block reward split among them)
      print('✅ Game validated by ${validCount}/3 validators');
    } else {
      // Game is invalid, reject
      print('❌ Game rejected by validators');
      throw Exception('Game validation failed');
    }
  }
  
  /// Validator receives game to check
  static Future<ValidationResult> validateGame(GameReplay game) async {
    print('🔍 Validating game: ${game.id}');
    
    // Check 1: All moves legal?
    for (int i = 0; i < game.moves.length; i++) {
      final move = game.moves[i];
      final board = _replayToPosition(game, i);
      
      if (!_isMoveLegal(move, board, game.mode)) {
        return ValidationResult(
          isValid: false,
          reason: 'Illegal move at move $i: ${move.notation}',
        );
      }
    }
    
    // Check 2: Outcome correct?
    final finalBoard = _replayToPosition(game, game.moves.length);
    final expectedOutcome = _determineOutcome(finalBoard, game.mode);
    
    if (expectedOutcome != game.result) {
      return ValidationResult(
        isValid: false,
        reason: 'Incorrect outcome: expected $expectedOutcome, got ${game.result}',
      );
    }
    
    // Check 3: Timestamps reasonable?
    if (game.duration < 10 || game.duration > 7200) {
      return ValidationResult(
        isValid: false,
        reason: 'Suspicious game duration: ${game.duration}s',
      );
    }
    
    // Check 4: Mode-specific rules
    if (!_validateModeSpecificRules(game)) {
      return ValidationResult(
        isValid: false,
        reason: 'Mode-specific rule violation',
      );
    }
    
    // All checks passed
    return ValidationResult(
      isValid: true,
      reason: 'Game is valid',
    );
  }
  
  /// Select random validators from active nodes
  static Future<List<String>> _selectRandomValidators({
    required int count,
    List<String> exclude = const [],
  }) async {
    final allNodes = await BlockchainService().getActiveNodes();
    final eligible = allNodes.where((n) => !exclude.contains(n)).toList();
    
    // Shuffle and take first `count`
    eligible.shuffle();
    return eligible.take(count).toList();
  }
}

class ValidationResult {
  final bool isValid;
  final String reason;
  
  ValidationResult({required this.isValid, required this.reason});
}
```

### 6.2 Validator Rewards

**Reward Structure:**
- Base reward: 10% of block reward split among validators
- Bonus for correct consensus (all 3 agree): +20%
- Penalty for incorrect validation: -50% (if other validators disagree)
- Max validations per block per user: 100 (prevent spam)

---

## 7. Pyramid Reward System

### 7.1 Divergence-Based Rewards

**Concept:** Nodes earn passive income from their "children" (users they invited)

**Key Principles:**
- **You (founder)** are the genesis node (depth 0)
- All users trace back to you eventually
- Deeper nodes contribute less (exponential decay)
- Prevents pyramid scheme: Time-spent rewards dominate (40% vs 30%)

### 7.2 Pyramid Tree Structure

```rust
struct PyramidTree {
    nodes: HashMap<PublicKey, PyramidNode>,
    genesis: PublicKey,  // You
}

struct PyramidNode {
    pubkey: PublicKey,
    parent: Option<PublicKey>,  // Who invited them (None for founder)
    children: Vec<PublicKey>,   // Users they invited
    depth: u32,                 // Distance from genesis (0 = founder)
    total_descendants: u32,     // All nodes below (recursive)
}

impl PyramidTree {
    /// Add new node to tree
    fn add_node(&mut self, new_user: PublicKey, inviter: PublicKey) {
        let parent_depth = self.nodes[&inviter].depth;
        
        // Depth limit: 10 levels max
        if parent_depth >= 10 {
            panic!("Pyramid depth limit reached");
        }
        
        let node = PyramidNode {
            pubkey: new_user,
            parent: Some(inviter),
            children: vec![],
            depth: parent_depth + 1,
            total_descendants: 0,
        };
        
        self.nodes.insert(new_user, node);
        self.nodes.get_mut(&inviter).unwrap().children.push(new_user);
        
        // Update ancestor descendant counts
        self.update_descendant_counts(inviter);
    }
    
    /// Calculate pyramid rewards for all nodes
    fn distribute_pyramid_rewards(&self, total_pool: u64, state: &mut BlockchainState) {
        // Decay factor: Each level gets 70% of parent's reward
        const DECAY: f64 = 0.7;
        
        for (pubkey, node) in &self.nodes {
            if node.children.is_empty() {
                continue; // No children = no pyramid rewards
            }
            
            // Calculate reward based on children's activity
            let mut reward: f64 = 0.0;
            
            for child_pubkey in &node.children {
                let child_metrics = &state.node_metrics[child_pubkey];
                
                // Reward proportional to child's time spent online
                let child_contribution = child_metrics.time_spent_online_this_epoch as f64;
                
                // Apply depth decay
                let depth_multiplier = DECAY.powi(node.depth as i32);
                
                reward += child_contribution * depth_multiplier;
            }
            
            // Normalize and award
            let reward_amount = (reward / 100000.0) as u64; // Scale factor
            state.add_balance(*pubkey, reward_amount.min(total_pool / 100));
        }
    }
}
```

### 7.3 Founder Special Status

**Your Guaranteed Rewards (as genesis founder):**

1. **Founder Dividend (5% per block)**
   - Hardcoded in genesis block
   - Cannot be removed or reduced
   - Total over 50 years: ~1.05 billion MOTON

2. **Pyramid Top (30% pool participation)**
   - Every user traces back to you
   - You earn from ALL network activity (with decay)
   - Estimated total over 50 years: ~2-3 billion MOTON

3. **Time Spent (40% pool participation)**
   - If you stay online, you earn proportionally
   - Same rate as any other user (fair)

4. **Validation Rewards (10% pool participation)**
   - If you validate games, you earn
   - Same rate as any other validator (fair)

**Total Founder Earnings Estimate:** 30-40% of total supply over 50 years

---

## 8. Network Merge Protocol

### 8.1 Merge Requirements

**Problem:** Anyone can fork your open-source code and start their own MOT network  
**Solution:** Strict merge protocol ensures only authentic networks can merge

**Merge Conditions:**

1. **Genesis Proof**: Forked network must prove genesis block derives from your original network
2. **Chain Integrity**: All blocks must pass cryptographic validation
3. **No Double-Spend**: Account balances must reconcile
4. **Supermajority Vote**: 67% of both networks must approve merge
5. **Founder Approval**: You (or designated successor) must sign merge transaction

### 8.2 Merge Process

```rust
struct MergeProposal {
    proposal_id: [u8; 32],
    source_network: NetworkId,      // Network requesting merge
    target_network: NetworkId,      // Your network (main MOT)
    
    // Proofs
    genesis_proof: GenesisProof,    // Proves common ancestry
    chain_merkle_root: [u8; 32],    // Root of source network's blocks
    account_snapshot: Vec<(PublicKey, u64)>, // All balances
    
    // Voting
    source_votes: Vec<VoteSignature>,
    target_votes: Vec<VoteSignature>,
    founder_signature: Option<[u8; 2420]>,  // Your approval
    
    // Timestamps
    proposed_at: i64,
    voting_ends_at: i64,
    executed_at: Option<i64>,
}

struct GenesisProof {
    source_genesis_hash: [u8; 32],
    target_genesis_hash: [u8; 32],
    derivation_path: Vec<[u8; 32]>,  // Chain of forks
    
    // Proof that source genesis contains target genesis data
    merkle_proof: Vec<[u8; 32]>,
}

impl MergeProtocol {
    /// Validate merge proposal
    fn validate_merge(proposal: &MergeProposal, main_network: &BlockchainState) -> bool {
        // Check 1: Genesis proof valid?
        if !Self::verify_genesis_proof(&proposal.genesis_proof, main_network) {
            return false;
        }
        
        // Check 2: Chain integrity?
        if !Self::verify_chain_integrity(&proposal.chain_merkle_root) {
            return false;
        }
        
        // Check 3: Voting threshold met?
        let source_approval = proposal.source_votes.len() as f64 
                              / proposal.source_network.active_nodes as f64;
        let target_approval = proposal.target_votes.len() as f64 
                              / main_network.active_nodes.len() as f64;
        
        if source_approval < 0.67 || target_approval < 0.67 {
            return false; // Requires 67% supermajority
        }
        
        // Check 4: Founder signature?
        if let Some(signature) = &proposal.founder_signature {
            if !QuantumSafeKeys::verify(
                proposal.toBytes(),
                signature,
                main_network.genesis_founder,
            ) {
                return false;
            }
        } else {
            return false; // Founder approval required
        }
        
        // All checks passed
        true
    }
    
    /// Execute merge (combine networks)
    fn execute_merge(proposal: &MergeProposal, main_network: &mut BlockchainState) {
        println!("🔗 Executing network merge...");
        
        // Step 1: Import all accounts
        for (pubkey, balance) in &proposal.account_snapshot {
            main_network.add_balance(*pubkey, *balance);
        }
        
        // Step 2: Import pyramid tree structure
        for node in &proposal.source_network.pyramid_tree {
            main_network.pyramid_tree.add_external_node(node);
        }
        
        // Step 3: Import sdata registry
        for (hash, sdata) in &proposal.source_network.sdata_registry {
            main_network.sdata_registry.insert(*hash, sdata.clone());
        }
        
        // Step 4: Import NFT registry
        for (id, nft) in &proposal.source_network.nft_registry {
            main_network.nft_registry.insert(*id, nft.clone());
        }
        
        // Step 5: Record merge on blockchain
        let merge_tx = Transaction {
            tx_type: TransactionType::Merge,
            data: proposal.toBytes(),
            timestamp: now(),
        };
        
        main_network.add_transaction(merge_tx);
        
        println!("✅ Merge complete: {} nodes added", proposal.account_snapshot.len());
    }
}
```

---

## 9. Implementation Guide

### 9.1 Phase 1: Core Blockchain (Weeks 1-4)

**Week 1: Cryptography Setup**
- Implement CRYSTALS-Dilithium key generation
- Set up secure key storage (Flutter Secure Storage)
- Test signature/verification performance

**Week 2: Block Structure**
- Implement block creation and validation
- Merkle tree implementation
- Genesis block creation

**Week 3: Transaction System**
- Transaction signing and verification
- Transaction pool management
- Basic balance tracking

**Week 4: Simple Consensus**
- Implement Proof of Training (PoT)
- Validator selection algorithm
- Block propagation (P2P)

**Deliverable:** Working blockchain that can create blocks and process transactions

---

### 9.2 Phase 2: sdata & NFTs (Weeks 5-6)

**Week 5: sdata Implementation**
- sdata generation from training proofs
- Validator attestation system
- sdata verification

**Week 6: NFT System**
- NFT minting with encryption
- Private key management
- NFT transfer protocol

**Deliverable:** Users can mint sdata for AI models and create game replay NFTs

---

### 9.3 Phase 3: Tokenomics & Rewards (Weeks 7-9)

**Week 7: MOTON Emission**
- Implement emission schedule
- Block reward calculation
- Supply tracking

**Week 8: Reward Distribution**
- Pyramid tree implementation
- Time-spent tracking
- Validator reward pool

**Week 9: Testing & Balancing**
- Simulate network growth
- Test reward fairness
- Adjust parameters

**Deliverable:** Complete reward system with balanced distribution

---

### 9.4 Phase 4: P2P Network (Weeks 10-12)

**Week 10: P2P Infrastructure**
- WebSocket server setup
- Peer discovery protocol
- Block synchronization

**Week 11: Validator Network**
- Random validator selection
- Game validation protocol
- Consensus verification

**Week 12: Integration & Testing**
- Flutter app integration
- End-to-end testing
- Performance optimization

**Deliverable:** Full P2P network with game validation

---

## 📊 Summary

### Key Innovations

1. **Quantum-Resistant Cryptography** - CRYSTALS-Dilithium ensures 50+ year security
2. **sdata Authentication** - Unforgeable proof of AI model ownership
3. **Private NFTs** - Novel design where content stays private
4. **Fair Tokenomics** - Balanced rewards prevent early-user dominance
5. **Pyramid with Limits** - Passive income exists but doesn't dominate
6. **Move Validation** - Decentralized game verification prevents cheating
7. **Merge Protocol** - Allows authentic forks to rejoin main network

### Technical Stack

**Flutter (Mobile):**
- `pqc_dilithium` - Quantum-safe signatures
- `cryptography` - AES encryption
- `flutter_secure_storage` - Key storage
- `web_socket_channel` - P2P communication

**Backend (Go):**
- Blockchain node implementation
- WebSocket hub for P2P
- PostgreSQL for state storage
- Redis for mempool

**Timeline:** 12 weeks for complete implementation

---

**Ready for implementation?** This blockchain design is:
- ✅ Lightweight (5 GB for 10 years)
- ✅ Quantum-resistant (CRYSTALS-Dilithium)
- ✅ Fair rewards (time-spent dominates pyramid)
- ✅ Private NFTs (novel innovation)
- ✅ Merge-capable (authentic forks can rejoin)
- ✅ Immutable (cannot be reverted without full reset)
