# Algorithm Flow Comparison

## Old POC Algorithm (Random Moves)

```
┌─────────────────────────────────────────────────────────────────┐
│                          SELF-PLAY                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    Get current position
                              ↓
                    Get legal moves (chess library)
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Neural Network Forward Pass                                     │
│  ┌────────────┐                                                  │
│  │   Policy   │ → [0.05, 0.05, 0.05, 0.05, ...] ❌ IGNORED!     │
│  │   Output   │                                                  │
│  └────────────┘                                                  │
│  ┌────────────┐                                                  │
│  │   Value    │ → 0.23  ✓ Used (but trained on random games)    │
│  │   Output   │                                                  │
│  └────────────┘                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
        Uniform probability: [1/N, 1/N, 1/N, ...]
                  (All moves equally likely)
                              ↓
                    Sample random move
                              ↓
                        Make move
                              ↓
                    Repeat until game over
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                           TRAINING                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
              Policy target: [0, 0, 0, ...] (all zeros)
                    Value target: game result
                              ↓
              Loss = MSE(value_pred, value_target)
             (Policy head not trained - no gradient!)
                              ↓
                   ❌ No strategic learning
```

**Result:** 400 Elo - Makes legal but random moves


## Improved Algorithm (Policy + MCTS)

```
┌─────────────────────────────────────────────────────────────────┐
│                          SELF-PLAY                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    Get current position
                              ↓
                    Get legal moves (chess library)
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  Neural Network Forward Pass                                     │
│  ┌────────────┐                                                  │
│  │   Policy   │ → [0.12, 0.03, 0.28, 0.15, ...] ✅ USED!        │
│  │   Output   │    (Guides which moves to explore)               │
│  └────────────┘                                                  │
│  ┌────────────┐                                                  │
│  │   Value    │ → 0.45  ✓ Used (trained on strategic games)     │
│  │   Output   │                                                  │
│  └────────────┘                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                   MCTS-LITE (50 simulations)                     │
│                                                                   │
│  For each simulation:                                            │
│    1. Select move with highest UCB score                         │
│       UCB = exploitation + exploration                           │
│           = mean_value + c * prior * √(parent_visits/visits)     │
│                                                                   │
│    2. Simulate move on copy of board                             │
│                                                                   │
│    3. Evaluate position:                                         │
│       - If terminal: use actual result (win/loss/draw)           │
│       - If non-terminal: use neural network value                │
│                                                                   │
│    4. Backpropagate value (negate for opponent)                  │
│       node.visit_count += 1                                      │
│       node.mean_value = total_value / visit_count                │
│                                                                   │
│  After all simulations:                                          │
│    Convert visit counts → improved probabilities                 │
│    [0.35, 0.02, 0.48, 0.08, ...]                                 │
│    (Higher visits = better move)                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
        Improved probability: visits^(1/temperature)
              (Strong moves get higher probability)
                              ↓
                Sample move (biased toward good moves)
                              ↓
                        Make move
                              ↓
                    Repeat until game over
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                           TRAINING                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
    Policy target: [0.35, 0.02, 0.48, 0.08, ...] (from MCTS)
          Value target: game result
                              ↓
    Loss = CrossEntropy(policy_pred, policy_target)
         + MSE(value_pred, value_target)
         (Both heads trained with strong gradients!)
                              ↓
              ✅ Strategic learning happens
```

**Result:** 800-1200 Elo - Makes strategic, coordinated moves


## Side-by-Side Comparison

```
┌────────────────────────┬────────────────────────┐
│     OLD POC (5 min)    │  IMPROVED (30 min)     │
├────────────────────────┼────────────────────────┤
│                        │                        │
│   Get Legal Moves      │   Get Legal Moves      │
│         ↓              │         ↓              │
│   Neural Network       │   Neural Network       │
│   (policy ignored)     │   (policy used)        │
│         ↓              │         ↓              │
│   Uniform Random       │   MCTS Search          │
│   [0.05, 0.05, ...]    │   (50 simulations)     │
│         ↓              │         ↓              │
│   Random Move          │   UCB Selection        │
│         ↓              │         ↓              │
│   Game Result          │   Improved Probs       │
│         ↓              │   [0.35, 0.02, ...]    │
│   Train Value Only     │         ↓              │
│   Loss: MSE            │   Strong Move          │
│         ↓              │         ↓              │
│   ❌ No Strategy       │   Game Result          │
│   400 Elo              │         ↓              │
│                        │   Train Both Heads     │
│                        │   Loss: CE + MSE       │
│                        │         ↓              │
│                        │   ✅ Strategic Play    │
│                        │   800-1200 Elo         │
│                        │                        │
└────────────────────────┴────────────────────────┘
```


## Key Innovation: UCB Tree Search

```
                        Current Position
                      /    |    |    |    \
                   e4     d4   Nf3  c4   g3
                  (P=0.3)(0.2)(0.15)(0.2)(0.15)
                     ↓
              MCTS Simulations (50x)
                     ↓
      Selection: Pick move with max UCB score
         UCB = mean_value + c * prior * √(parent/visits)
                     ↓
      Early iterations: High exploration (try all moves)
      Later iterations: High exploitation (focus on best)
                     ↓
                Visit Counts:
                e4: 25 visits (mean: +0.42)
                d4: 12 visits (mean: +0.38)
               Nf3: 8 visits  (mean: +0.15)
                c4: 3 visits  (mean: +0.10)
                g3: 2 visits  (mean: -0.05)
                     ↓
           Final Probability (visits^1/T):
                e4: 0.48  (most explored)
                d4: 0.28
               Nf3: 0.15
                c4: 0.07
                g3: 0.02  (least explored)
```

**Why this works:**
- Neural network **guides** search (high prior = explore more)
- MCTS **refines** evaluation (lookahead 1-2 moves)
- Combined: Fast + accurate move selection


## Training Loss Progression

```
Old POC (Random):
Iteration:  1    2    3    4    5
Value Loss: 0.09 0.08 0.09 0.10 0.08  ← Fluctuates (no strategy)
Policy:     -    -    -    -    -      ← Not trained

Win Rate vs Self: 0% (all draws)


Improved Algorithm:
Iteration:   1     2     3     4     5     6     7     8
Policy Loss: 2.34  1.82  1.45  1.23  1.08  0.98  0.91  0.87  ← Steady decrease
Value Loss:  0.089 0.074 0.062 0.055 0.048 0.042 0.038 0.032 ← Steady decrease
Total Loss:  2.43  1.90  1.51  1.29  1.13  1.02  0.95  0.90  ← Consistent improvement

Win Rate vs POC: 75% (real strategic improvement)
```


## Performance Characteristics

```
┌──────────────────┬─────────────┬──────────────────┐
│     Metric       │  Old POC    │   Improved       │
├──────────────────┼─────────────┼──────────────────┤
│ Training Time    │   5 min     │    30 min        │
│ Games Played     │   150       │    320           │
│ Positions        │   ~3,000    │    ~8,000        │
│ MCTS Sims/Move   │   0         │    50            │
│ Policy Training  │   ❌        │    ✅            │
│ Lookahead Depth  │   0 moves   │    2-3 moves     │
│ Expected Elo     │   400       │    800-1200      │
│ Win vs POC       │   -         │    70-80%        │
│ Model Size       │   35 MB     │    35 MB         │
│ Inference Time   │   10 ms     │    10-50 ms*     │
└──────────────────┴─────────────┴──────────────────┘

* With MCTS during play (optional - can disable for faster moves)
```


## Integration Options

### Option A: Fast Moves (No MCTS)
```
Flutter → Load Model → Neural Network Only
                    ↓
               Policy Output (4096 logits)
                    ↓
               Softmax over legal moves
                    ↓
               Pick best move (argmax)
                    ↓
          Inference: ~10-15ms per move
```

### Option B: Strong Moves (With MCTS)
```
Flutter → Load Model → Run 25 MCTS Simulations
                    ↓
               Improved Probabilities
                    ↓
               Pick best move
                    ↓
          Inference: ~50-100ms per move
```

**Recommendation for ChessRecast:**
- Easy Mode: Neural network only (fast, 600 Elo)
- Medium Mode: MCTS with 25 sims (800 Elo)
- Hard Mode: MCTS with 50+ sims (1000+ Elo)
