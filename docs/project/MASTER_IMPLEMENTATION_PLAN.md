# ChessRecast - Master Implementation Plan
**Version**: 2.0  
**Created**: December 11, 2025  
**Document Type**: Project Coordination & Navigation  
**Status**: Strategic Planning Complete

---

## 📖 Document Overview

This is the **master index** for ChessRecast's complete implementation. It coordinates three major strategic roadmaps and provides guidance for any AI assistant or developer continuing this project.

---

## 🎯 Project Vision

**ChessRecast** is building a revolutionary chess platform with:
- **12 Custom Chess Variants** (8 active, 4 in development) with unique rules and mechanics
- **Pure Dart Chess Engine** — Minimax + Alpha-Beta Pruning with Iterative Deepening, Quiescence Search, Null Move Pruning, LMR, Transposition Tables, and hand-crafted evaluation (mod-aware)
- **Bot vs Human Play** powered entirely by the in-app engine (no external dependencies)
- **Engine Lab** — watch the engine play itself with configurable levels and real-time stats
- **Quantum-Resistant Blockchain** (MOT) for validation and rewards
- **Private NFT System** for game replay ownership
- **Fair Token Economics** with pyramid + time-spent rewards

---

## 📚 Documentation Structure

### Core Documentation

| Document | Purpose | Location |
|----------|---------|----------|
| **[README.md](../../README.md)** | Project overview & quick start | Root |
| **[MASTER_IMPLEMENTATION_PLAN.md](./MASTER_IMPLEMENTATION_PLAN.md)** | This document - project coordination | docs/project/ |
| **[GAME_MODS_DOCUMENTATION.md](./GAME_MODS_DOCUMENTATION.md)** | Full rules for all 12 game mods | docs/project/ |
| **[BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md](./BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md)** | MOT blockchain system | docs/project/ |

### Engine Architecture

The chess engine lives in `frontend/lib/engine/` and consists of:

| File | Purpose |
|------|--------|
| `transposition.dart` | Zobrist hashing & transposition table (32MB default) |
| `move_ordering.dart` | MVV-LVA, killer moves (2 per ply), history heuristic |
| `evaluation.dart` | Material, piece-square tables, pawn structure, king safety, mod-specific bonuses |
| `search.dart` | Alpha-Beta + Iterative Deepening + Quiescence Search + Null Move Pruning + LMR |
| `engine.dart` | Public API — `ChessEngine.findBestMove()` (async via Isolate) and `findBestMoveSync()` |

Engine levels: Easy (depth 2), Medium (depth 4), Hard (depth 6), Expert (depth 8), Maximum (depth 64).

**Note for AI Assistants**: There is no external AI training or TFLite model. The bot uses a pure Dart Minimax engine.

---

## 🗓️ Complete Timeline (26 Weeks)

```
┌─────────────────────────────────────────────────────────────────┐
│               PHASE 1: CHESS ENGINE (COMPLETE)                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Goal: Pure Dart chess engine for all game mods             │ │
│  │                                                             │ │
│  │ ✅ Transposition table with Zobrist hashing                │ │
│  │ ✅ Move ordering (MVV-LVA, killer moves, history)          │ │
│  │ ✅ Hand-crafted evaluation with mod-specific bonuses       │ │
│  │ ✅ Alpha-Beta + Iterative Deepening + Quiescence Search    │ │
│  │ ✅ Null Move Pruning + Late Move Reductions                │ │
│  │ ✅ 5 difficulty levels (Easy → Maximum)                    │ │
│  │ ✅ Engine Lab UI for watching engine self-play              │ │
│  │                                                             │ │
│  │ Deliverable: Playable engine bot in Flutter app            │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 3: P2P GAMENET                          │
│                        Weeks 13-18                               │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Goal: Enable distributed training & model sharing          │ │
│  │                                                             │ │
│  │ Week 13: GameNet architecture design                       │ │
│  │ Weeks 14-15: Bootstrap server implementation              │ │
│  │ Week 16: Flutter P2P client + local storage               │ │
│  │ Week 17: On-device incremental training                   │ │
│  │ Week 18: Network testing & optimization                   │ │
│  │                                                             │ │
│  │ Deliverable: Working P2P training network                 │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 PHASE 4: BLOCKCHAIN INTEGRATION                  │
│                        Weeks 19-26                               │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Goal: MOT blockchain for validation & rewards              │ │
│  │                                                             │ │
│  │ Weeks 19-20: Quantum-proof cryptography                   │ │
│  │ Weeks 21-22: Blockchain core (blocks, consensus)          │ │
│  │ Weeks 23-24: sdata & private NFT systems                  │ │
│  │ Weeks 25-26: Tokenomics & reward distribution             │ │
│  │                                                             │ │
│  │ Deliverable: Complete MOT blockchain system               │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

Total Duration: 18 weeks (reduced — engine phase already complete)
```

---

## 🎯 Phase-by-Phase Breakdown

### Phase 1: Chess Engine (Complete)

**Objective**: Build a pure Dart chess engine supporting all game mods

**Key Milestones**:
- ✅ Zobrist hashing & transposition table
- ✅ Move ordering (MVV-LVA, killer moves, history heuristic)
- ✅ Hand-crafted evaluation with piece-square tables, pawn structure, king safety
- ✅ Mod-specific evaluation bonuses (Mercenary, Succession, etc.)
- ✅ Alpha-Beta search with Iterative Deepening
- ✅ Quiescence Search with check evasions
- ✅ Null Move Pruning + Late Move Reductions
- ✅ 5 difficulty levels (Easy through Maximum)
- ✅ Async search via `Isolate.run`
- ✅ Engine Lab UI for watching engine self-play

**Success Criteria**:
- Engine plays legal moves in all 8 active mods
- Search runs in background isolate (non-blocking)
- Configurable difficulty via depth and time limits
- `dart analyze lib/` passes with zero errors/warnings

**Architecture** (`frontend/lib/engine/`):
- `transposition.dart` — Zobrist hashing + TranspositionTable
- `move_ordering.dart` — MVV-LVA, killer moves, history heuristic
- `evaluation.dart` — Material, PST, pawn structure, king safety, mod bonuses
- `search.dart` — Alpha-Beta + ID + QSearch + NMP + LMR
- `engine.dart` — Public API with `EngineLevel` enum

---

### Phase 2: P2P GameNet (Weeks 1-6)

**Objective**: Enable online play and model sharing via P2P network

**Key Milestones**:
- ✅ Week 1: Network protocol designed
- ✅ Week 3: Bootstrap server operational
- ✅ Week 4: Flutter P2P client connects successfully
- ✅ Week 5: Online bot play working
- ✅ Week 6: Network scales to 100+ peers

**Success Criteria**:
- Network remains stable with 100+ peers
- Online bot matches work reliably
- User privacy maintained (encryption + opt-in)

**Critical Path Items**:
1. WebSocket hub server
2. Peer discovery protocol
3. Online bot game orchestration

---

### Phase 3: Blockchain Integration (Weeks 7-18)

**Document**: [BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md](./BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md)

**Objective**: Implement MOT blockchain for training validation and MOTON rewards

**Key Milestones**:
- ✅ Week 20: Quantum-safe cryptography working
- ✅ Week 22: Blockchain core operational
- ✅ Week 24: sdata & NFT systems live
- ✅ Week 26: Tokenomics balanced, rewards distributed

**Success Criteria**:
- Blockchain survives 50+ years (quantum-resistant)
- sdata proves game authenticity
- NFT content stays private (encrypted)
- MOTON distribution is fair (time-spent > pyramid)
- Total supply never exceeds 21B
- **Divergence mathematics**: "More nodes diverge from you = more rewards"
- **"all / 1 = all" principle**: Founder earns from entire network
- **Fair balance**: Gap grows over time but late joiners can compete via activity

**Reward System Details** (Critical - thoroughly specified in roadmap):
1. **Competition rules**:
   - Time spent online: 40% of block reward (DOMINANT)
   - Game validation: 10% of block reward
   - Training contribution: 15% of block reward
   - Ensures active users earn more than passive users

2. **Divergence rewards** (pyramid):
   - 30% of block reward distributed via pyramid tree
   - Formula: `directChildren * log(1 + totalDescendants)`
   - More branches = more passive income
   - Depth decay: 70% per level (prevents exponential unfairness)
   - Founder at root: Divergence score compounds massively over time
   - **Critical**: You only earn from YOUR descendants' activity (not entire network)
   - **Over time**: As network grows, founder's divergence score becomes exponentially large
   - **Registration mechanism**: New users register via P2P (not invitation)

3. **"all / 1 = all" mathematics**:
   - With 1 user (you): 100% of pyramid pool
   - With 10 users: ~60% of pyramid pool
   - With 1000 users: ~40% of pyramid pool
   - With 10,000 users: ~25% of pyramid pool
   - Percentage decreases BUT absolute MOTON increases

4. **Fairness over time**:
   - Near term (year 1-2): Small gap (founder ~3x early adopter)
   - Mid term (year 5): Medium gap (founder ~30x year 5 user)
   - Long term (year 10+): Large gap (founder ~40x year 10 user)
   - Gap grows naturally (as intended) but remains fair because:
     - Time-spent rewards (40%) > Pyramid rewards (30%)
     - Active late users can out-earn passive early users
     - Supply continues growing (late users get absolute MOTON)

5. **Founder dividend**:
   - 5% of every block reward (guaranteed)
   - Compounds over 50 years
   - Total founder earnings over lifetime: ~15-20% of total supply

**Hardware Requirements**:
- Blockchain nodes: 2GB RAM, 10GB storage
- User devices: <100MB blockchain storage

**Blockchain Immutability & Fork Management**:
1. **Genesis Lock**: Once MOT starts, no way to revert or reset (unless starting new network)
2. **Open Source Freedom**: Anyone can fork code and start independent MOT network
3. **Authenticity Verification**: Only YOUR genesis hash + founder key = authentic MOT
4. **Fork Detection**: Automatic detection of authentic vs fake forks
5. **Merge Rules** (for network splits):
   - Must have same genesis (authentic only)
   - Longest chain wins (most Proof of Training work)
   - Conflicting transactions: Winner chain's version kept
   - Lost transactions return to mempool
6. **Anti-Tampering**: Cryptographic proof prevents hijacking, cannot counterfeit

**Critical Path Items**:
1. CRYSTALS-Dilithium key generation
2. Block structure and validation
3. sdata authentication system
4. Private NFT implementation
5. Tokenomics and reward distribution (with divergence mathematics)
6. Economic simulations (verify fairness over 10+ years)
7. Fork detection and authentic merge system
8. Genesis immutability enforcement

---

## 🔄 Implementation Workflow

### For AI Assistants Starting a New Session

**Step 1: Determine Current Phase**
```
Read MASTER_IMPLEMENTATION_PLAN.md (this file)
↓
Check which phase is active:
- Phase 1: Chess Engine (check frontend/lib/engine/) — COMPLETE
- Phase 2: P2P network (look for GameNet services)
- Phase 3: Blockchain (look for cryptography services)
```

**Step 2: Open Appropriate Roadmap**
```
Phase 2: This document (P2P GameNet section)
Phase 3: BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md
```

**Step 3: Find Current Step**
```
Scan roadmap for completion markers
Find first uncompleted step
Verify dependencies are met
```

**Step 4: Execute Step**
```
Read: Actions, Expected Outcomes, Validation
Implement: Follow actions systematically
Test: Run validation commands
Document: Mark step complete
```

**Step 5: Repeat**
```
Move to next step
Continue until phase complete
Update progress tracking
```

### Quick Status Check Commands

**Check Phase 1 Status (Chess Engine)**:
```bash
# Check engine files exist
ls frontend/lib/engine/
# Should see: transposition.dart, move_ordering.dart, evaluation.dart, search.dart, engine.dart

# Check Engine Lab UI
ls frontend/lib/ui/watch_engine_page.dart
ls frontend/lib/management/watch_engine_controller.dart

# Run static analysis
cd frontend && dart analyze lib/
```

**Check Phase 2 Status (P2P)**:
```bash
# Check bootstrap server
curl http://localhost:8765/status

# Check Flutter P2P service
grep -r "GameNetService" frontend/lib/services/
```

**Check Phase 3 Status (Blockchain)**:
```bash
# Check cryptography
grep -r "QuantumSafeKeys" frontend/lib/services/crypto/

# Check blockchain core
grep -r "Block" frontend/lib/services/blockchain/
```

---

## 📊 Progress Tracking

### Completion Checklist

**Phase 1: Chess Engine**
- [x] Transposition table with Zobrist hashing
- [x] Move ordering (MVV-LVA, killer moves, history)
- [x] Hand-crafted evaluation with mod-specific bonuses
- [x] Alpha-Beta + Iterative Deepening + Quiescence Search
- [x] Null Move Pruning + Late Move Reductions
- [x] 5 difficulty levels
- [x] Engine Lab UI

**Phase 2: P2P GameNet**
- [ ] Week 13: Protocol designed
- [ ] Week 14-15: Bootstrap server running
- [ ] Week 16: Flutter P2P client working
- [ ] Week 17: On-device training active
- [ ] Week 18: Network tested at scale

**Phase 3: Blockchain**
- [ ] Week 19-20: Cryptography implemented
- [ ] Week 21-22: Blockchain core operational
- [ ] Week 23-24: sdata & NFTs working
- [ ] Week 25-26: Tokenomics balanced

---

## ⚠️ Critical Success Factors

### Must-Have Before Launch

1. **Engine Quality**:
   - Engine plays legal moves in all active mods
   - Search runs without blocking the UI
   - 5 difficulty levels provide varied challenge

2. **P2P Stability**:
   - Network scales to 100+ peers
   - No data corruption
   - Handles disconnections gracefully

3. **Blockchain Security**:
   - Quantum-resistant cryptography verified
   - Economic simulations pass (fair distribution)
   - Third-party security audit complete

4. **User Experience**:
   - Offline play works perfectly
   - No crashes or freezes
   - Clear onboarding flow

5. **Documentation**:
   - All roadmaps complete
   - API documentation written
   - Deployment guide ready

### Known Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Training takes longer than 5 days/mode | N/A | N/A | Replaced by Dart engine |
| Mobile inference too slow | Low | Medium | Engine runs in isolate, configurable depth |
| P2P network doesn't scale | Medium | High | Keep bootstrap server as relay |
| Blockchain bloat | Low | Medium | Increase block time, prune old blocks |
| Economic imbalance | Medium | High | Run simulations, adjust percentages before launch |

---

## 📝 Documentation Guidelines

### When to Update Roadmaps


**Update BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md when**:
- Cryptography algorithm changes
- Consensus mechanism changes
- Tokenomics percentages adjusted
- New transaction types needed

**Update MASTER_IMPLEMENTATION_PLAN.md when**:
- Timeline changes
- Phase priorities shift
- New critical success factors identified
- Major architectural decisions made

### Version Control

**Document Versions**:
- v1.0: Initial roadmaps (with code examples)
- v2.0: Strategic roadmaps (word-only, step-by-step) ← CURRENT

**When to Increment Version**:
- Major restructuring
- Significant scope changes
- Timeline adjustments >20%

---

## 🎓 Knowledge Transfer

### For Future Developers

**Essential Reading Order**:
1. **MASTER_IMPLEMENTATION_PLAN.md** (this file) - Understand overall structure
2. **GAME_MODS_DOCUMENTATION.md** - All 12 game mod rules
3. **BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md** - Learn blockchain design

**Key Concepts to Understand**:
- Minimax with Alpha-Beta pruning (chess engine)
- Iterative Deepening + Quiescence Search
- Transposition tables and Zobrist hashing
- Quantum-resistant cryptography (CRYSTALS-Dilithium)
- Proof of Training consensus
- Private NFT design
- Pyramid + time-spent rewards balance

**Common Mistakes to Avoid**:
- Don't change tokenomics after launch (immutable blockchain)
- Don't leak private keys (use secure storage)
- Don't ignore economic simulations (can't fix after launch)
- Don't modify engine evaluation without running Engine Lab to verify

---

## 🚀 Quick Start Guide

### For a New AI Assistant

**Your First Session:**

1. **Read this file completely** (MASTER_IMPLEMENTATION_PLAN.md)
2. **Determine current phase**:
   ```bash
   # Check engine files
   ls frontend/lib/engine/
   
   # Check for P2P services
   grep -r "GameNetService" frontend/lib/
   
   # Check for blockchain services
   grep -r "QuantumSafeKeys" frontend/lib/
   ```
3. **Open appropriate roadmap** (this doc or Blockchain)
4. **Find next uncompleted step**
5. **Begin implementation**

**Example Session Start**:
```
AI: "I'm reading MASTER_IMPLEMENTATION_PLAN.md..."

Checking current phase...
- frontend/lib/engine/ has 5 files ✅
- Phase 1 (Chess Engine) COMPLETE

Phase 2 (P2P GameNet) is next.
Checking for GameNet services... not found.
Phase 2 IN PROGRESS.

Next step: Design WebSocket hub server
[begins implementation]
```

---

## 📞 Contact & Resources

### Project Context
- **Project**: ChessRecast
- **Repository**: metaphy6/chessrecast
- **Branch**: main
- **Started**: December 11, 2025
- **Status**: Phase 1 (Chess Engine) complete, Phase 2 (P2P) next

### External Resources
- **NIST Post-Quantum Cryptography**: https://csrc.nist.gov/projects/post-quantum-cryptography
- **Chess Programming Wiki**: https://www.chessprogramming.org/
- **Docker Compose**: https://docs.docker.com/compose/

---

## ✅ Final Checklist Before Implementation

**Before starting next phase**:
- [ ] This document read and understood
- [ ] Development environment set up (Flutter, Docker, Git, VS Code)
- [ ] Engine Lab tested (verify engine plays correctly)
- [ ] Backup strategy defined

**Ready to begin?**
→ Phase 1 (Chess Engine) is complete  
→ Next: Phase 2 (P2P GameNet) — see section above  
→ Then: Phase 3 (Blockchain) — see [BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md](./BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md)  

---

**END OF MASTER PLAN**

This document serves as the navigation hub for ChessRecast's complete implementation. Any AI assistant or developer should start here, then navigate to the appropriate detailed roadmap for step-by-step implementation instructions.
