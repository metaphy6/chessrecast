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

**ChessRecast** is building a revolutionary AI-powered chess platform with:
- **12 Custom Chess Variants** (8 active, 4 in development) with unique rules and mechanics
- **Self-Learning AI Agents** trained via reinforcement learning
- **Distributed P2P Training** across user devices
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

### AI Documentation

| Document | Purpose | Location |
|----------|---------|----------|
| **[README.md](../ai/README.md)** | AI training overview & file structure | docs/ai/ |
| **[QUICKSTART.md](../ai/QUICKSTART.md)** | Quick start for Mercenary training | docs/ai/ |
| **[README_MERCENARY.md](../ai/README_MERCENARY.md)** | Mercenary mode training details | docs/ai/ |
| **[IMPROVED_ALGORITHM.md](../ai/IMPROVED_ALGORITHM.md)** | Policy-guided MCTS algorithm design | docs/ai/ |
| **[ALGORITHM_FLOW_COMPARISON.md](../ai/ALGORITHM_FLOW_COMPARISON.md)** | Old vs improved algorithm | docs/ai/ |

### Code References

| Document | Purpose | Location |
|----------|---------|----------|
| **[docker-commands.md](../code/docker-commands.md)** | Docker volume & cleanup | docs/code/ |
| **[db-commands.md](../code/db-commands.md)** | Database access & queries | docs/code/ |

**Note for AI Assistants**: The AI training system is actively maintained in `ai/trainer/`. Refer to `docs/ai/` for up-to-date training documentation.

---

## 🗓️ Complete Timeline (26 Weeks)

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHASE 1: AI FOUNDATION                        │
│                         Weeks 1-8                                │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Goal: Train 8 baseline AI models (900-1200 Elo)           │ │
│  │                                                             │ │
│  │ Week 1:  Project setup & infrastructure                    │ │
│  │ Week 2:  Neural network architecture                       │ │
│  │ Week 3:  Self-play engine (MCTS)                          │ │
│  │ Week 4:  Training loop & validation                       │ │
│  │ Week 5:  Train Classic mode (first model)                 │ │
│  │ Weeks 6-8: Train remaining 7 active modes                 │ │
│  │                                                             │ │
│  │ Deliverable: 8 trained PyTorch models                     │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                  PHASE 2: MOBILE INTEGRATION                     │
│                        Weeks 9-12                                │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Goal: Deploy AI to Flutter, enable offline play           │ │
│  │                                                             │ │
│  │ Week 9:  Convert PyTorch → TFLite (8 models)              │ │
│  │ Week 10: Flutter TFLite service + MCTS                    │ │
│  │ Week 11: UI integration & game controller                 │ │
│  │ Week 12: Testing, polish, optimization                    │ │
│  │                                                             │ │
│  │ Deliverable: Playable AI in Flutter app                   │ │
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

Total Duration: 26 weeks (6.5 months)
```

---

## 🎯 Phase-by-Phase Breakdown

### Phase 1: AI Foundation (Weeks 1-8)

**Document**: [AI_IMPLEMENTATION_ROADMAP_V2.md](./AI_IMPLEMENTATION_ROADMAP_V2.md)

**Objective**: Train 14 specialized AI models using self-play reinforcement learning

**Key Milestones**:
- ✅ Week 1: Docker infrastructure running, GPU accessible
- ✅ Week 2: Neural network implemented (policy-value network)
- ✅ Week 3: MCTS engine working, self-play generating games
- ✅ Week 4: Training loop converges, models improve
- ✅ Week 5: First model (Classic) reaches 900+ Elo
- ✅ Week 8: All 14 models trained to 900-1200 Elo

**Success Criteria**:
- Each model reaches 900+ Elo in self-play tournaments
- Models respect game rules (0% illegal moves)
- Training infrastructure stable (no crashes)
- Checkpoints saved and versioned

**Hardware Requirements**:
- RTX 4080 Mobile (12GB VRAM)
- Can train one mode at a time
- 3-5 days per mode

**Critical Path Items**:
1. Game rule validators for all 14 modes
2. Neural network architecture (policy-value)
3. MCTS implementation
4. Training loop with Elo evaluation

---

### Phase 2: Mobile Integration (Weeks 9-12)

**Document**: [AI_IMPLEMENTATION_ROADMAP_V2.md](./AI_IMPLEMENTATION_ROADMAP_V2.md) (Section: Phase 2)

**Objective**: Deploy AI models to Flutter app for offline play

**Key Milestones**:
- ✅ Week 9: All 14 models exported to TFLite (5-20MB each)
- ✅ Week 10: TFLite inference working in Flutter (<100ms)
- ✅ Week 11: Game UI integrated with AI
- ✅ Week 12: All edge cases handled, performance optimized

**Success Criteria**:
- Inference time <100ms on mid-range phones
- AI never makes illegal moves
- Users can play complete games offline
- 4 difficulty levels work correctly

**Hardware Requirements**:
- Android phones: 2-8GB RAM
- iOS phones: 2-8GB RAM
- GPU acceleration where available

**Critical Path Items**:
1. PyTorch → TFLite conversion pipeline
2. Flutter TFLite service implementation
3. MCTS engine ported to Dart
4. Game controller integration

---

### Phase 3: P2P GameNet (Weeks 13-18)

**Document**: [AI_IMPLEMENTATION_ROADMAP_V2.md](./AI_IMPLEMENTATION_ROADMAP_V2.md) (Section: Phase 3)

**Objective**: Enable distributed training across user devices via P2P network

**Key Milestones**:
- ✅ Week 13: Network protocol designed
- ✅ Week 15: Bootstrap server operational
- ✅ Week 16: Flutter P2P client connects successfully
- ✅ Week 17: On-device training improves models
- ✅ Week 18: Network scales to 100+ peers

**Success Criteria**:
- Network remains stable with 100+ peers
- Training data shared efficiently (<10MB/day per user)
- Models improve faster with federated learning
- User privacy maintained (encryption + opt-in)
- **Bots learn continuously on host devices** (resource-efficient)

**Resource-Efficient Learning Strategy**:
1. **Initial bots**: 500-700 Elo (small, fast, understand rules)
2. **Continuous learning**: Fine-tune on device when idle + charging
3. **Progressive growth**: 500 Elo → 900 Elo (Month 3) → 1600 Elo (Year 1)
4. **Resource constraints**: <10% CPU, only when battery >50%, pause if app active
5. **Validator eligibility**: Once bot reaches 900+ Elo, can earn MOTON
6. **Personal AI companion**: Bot grows with owner, adapts to their style

**Hardware Requirements**:
- Bootstrap server: Any modern server (2GB RAM sufficient)
- User devices: Training only when charging + WiFi, <10% CPU usage

**Critical Path Items**:
1. WebSocket hub server
2. Peer discovery protocol
3. Local encrypted model storage
4. On-device incremental training
5. Continuous learning engine (background fine-tuning)
6. Resource monitoring (battery, CPU, foreground state)

---

### Phase 4: Blockchain Integration (Weeks 19-26)

**Document**: [BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md](./BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md)

**Objective**: Implement MOT blockchain for training validation and MOTON rewards

**Key Milestones**:
- ✅ Week 20: Quantum-safe cryptography working
- ✅ Week 22: Blockchain core operational
- ✅ Week 24: sdata & NFT systems live
- ✅ Week 26: Tokenomics balanced, rewards distributed

**Success Criteria**:
- Blockchain survives 50+ years (quantum-resistant)
- sdata proves AI training authenticity
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
- Phase 1: AI training (look for trained models)
- Phase 2: Mobile deployment (look for TFLite models in Flutter)
- Phase 3: P2P network (look for GameNet services)
- Phase 4: Blockchain (look for cryptography services)
```

**Step 2: Open Appropriate Roadmap**
```
Phase 1-3: AI_IMPLEMENTATION_ROADMAP_V2.md
Phase 4: BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md
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

**Check Phase 1 Status (AI Training)**:
```bash
# Check if models trained
ls ai/models/checkpoints/
# Should see: classic/ heir/ snare/ ... (14 folders)

# Check training logs
docker-compose logs trainer | tail -100

# Check Elo ratings
python evaluate_elo.py --all-modes
```

**Check Phase 2 Status (Mobile)**:
```bash
# Check TFLite models
ls frontend/assets/models/
# Should see: 14 .tflite files (5-20MB each)

# Check Flutter service
grep -r "TFLiteModelService" frontend/lib/services/
```

**Check Phase 3 Status (P2P)**:
```bash
# Check bootstrap server
curl http://localhost:8765/status

# Check Flutter P2P service
grep -r "GameNetService" frontend/lib/services/
```

**Check Phase 4 Status (Blockchain)**:
```bash
# Check cryptography
grep -r "QuantumSafeKeys" frontend/lib/services/crypto/

# Check blockchain core
grep -r "Block" frontend/lib/services/blockchain/
```

---

## 📊 Progress Tracking

### Completion Checklist

**Phase 1: AI Foundation**
- [ ] Week 1: Infrastructure setup complete
- [ ] Week 2: Neural network implemented
- [ ] Week 3: MCTS engine working
- [ ] Week 4: Training loop converges
- [ ] Week 5: Classic model at 900+ Elo
- [ ] Week 6-8: All 14 models trained

**Phase 2: Mobile Integration**
- [ ] Week 9: TFLite export complete
- [ ] Week 10: Flutter TFLite service working
- [ ] Week 11: Game UI integrated
- [ ] Week 12: Testing complete

**Phase 3: P2P GameNet**
- [ ] Week 13: Protocol designed
- [ ] Week 14-15: Bootstrap server running
- [ ] Week 16: Flutter P2P client working
- [ ] Week 17: On-device training active
- [ ] Week 18: Network tested at scale

**Phase 4: Blockchain**
- [ ] Week 19-20: Cryptography implemented
- [ ] Week 21-22: Blockchain core operational
- [ ] Week 23-24: sdata & NFTs working
- [ ] Week 25-26: Tokenomics balanced

---

## ⚠️ Critical Success Factors

### Must-Have Before Launch

1. **AI Quality**:
   - All 14 models reach 900+ Elo
   - 0% illegal moves
   - Inference <100ms on mobile

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
| Training takes longer than 5 days/mode | Medium | Medium | Use smaller models (32 channels) |
| Mobile inference too slow | Low | High | Aggressive quantization, GPU acceleration |
| P2P network doesn't scale | Medium | High | Keep bootstrap server as relay |
| Blockchain bloat | Low | Medium | Increase block time, prune old blocks |
| Economic imbalance | Medium | High | Run simulations, adjust percentages before launch |

---

## 📝 Documentation Guidelines

### When to Update Roadmaps

**Update AI_IMPLEMENTATION_ROADMAP_V2.md when**:
- Model architecture changes
- Training approach changes
- Hardware constraints change
- New game mods added

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
2. **AI_IMPLEMENTATION_ROADMAP_V2.md** - Learn AI system design
3. **BLOCKCHAIN_IMPLEMENTATION_ROADMAP_V2.md** - Learn blockchain design
4. Legacy docs (optional) - See code examples

**Key Concepts to Understand**:
- AlphaZero-style reinforcement learning
- Policy-value neural networks
- Monte Carlo Tree Search (MCTS)
- Quantum-resistant cryptography (CRYSTALS-Dilithium)
- Proof of Training consensus
- Private NFT design
- Pyramid + time-spent rewards balance

**Common Mistakes to Avoid**:
- Don't use pre-trained models (they don't understand custom rules)
- Don't skip validation steps (critical for quality)
- Don't change tokenomics after launch (immutable blockchain)
- Don't leak private keys (use secure storage)
- Don't ignore economic simulations (can't fix after launch)

---

## 🚀 Quick Start Guide

### For a New AI Assistant

**Your First Session:**

1. **Read this file completely** (MASTER_IMPLEMENTATION_PLAN.md)
2. **Determine current phase**:
   ```bash
   # Check for trained models
   ls ai/models/checkpoints/
   
   # Check for TFLite models
   ls frontend/assets/models/
   
   # Check for P2P services
   grep -r "GameNetService" frontend/lib/
   
   # Check for blockchain services
   grep -r "QuantumSafeKeys" frontend/lib/
   ```
3. **Open appropriate roadmap** (AI or Blockchain)
4. **Find next uncompleted step**
5. **Begin implementation**

**Example Session Start**:
```
AI: "I'm reading MASTER_IMPLEMENTATION_PLAN.md..."

Checking current phase...
- ai/models/checkpoints/ has 5 folders (not 14) ❌
- Phase 1 IN PROGRESS

Opening AI_IMPLEMENTATION_ROADMAP_V2.md...
Current location: Week 6, training 6th mode

Next step: Train mode #6 (Teleport)
Expected outcome: 900+ Elo in 3-5 days
Beginning training...

[executes training]
```

---

## 📞 Contact & Resources

### Project Context
- **Project**: ChessRecast
- **Repository**: metaphy6/chessrecast
- **Branch**: main
- **Started**: December 11, 2025
- **Status**: Strategic planning complete, ready for implementation

### External Resources
- **NIST Post-Quantum Cryptography**: https://csrc.nist.gov/projects/post-quantum-cryptography
- **AlphaZero Paper**: "Mastering Chess and Shogi by Self-Play with a General Reinforcement Learning Algorithm"
- **Flutter TFLite**: https://pub.dev/packages/tflite_flutter
- **Docker Compose**: https://docs.docker.com/compose/

---

## ✅ Final Checklist Before Implementation

**Before starting Week 1**:
- [ ] All three roadmap documents read and understood
- [ ] Hardware requirements met (RTX 4080 Mobile or equivalent)
- [ ] Development environment set up (Docker, Git, VS Code)
- [ ] Time commitment understood (26 weeks full-time)
- [ ] Backup strategy defined (code, models, checkpoints)

**Ready to begin?**
→ Open [AI_IMPLEMENTATION_ROADMAP_V2.md](./AI_IMPLEMENTATION_ROADMAP_V2.md)  
→ Start with Phase 1, Week 1, Step 1.1  
→ Follow step-by-step until complete  

---

**END OF MASTER PLAN**

This document serves as the navigation hub for ChessRecast's complete implementation. Any AI assistant or developer should start here, then navigate to the appropriate detailed roadmap for step-by-step implementation instructions.
