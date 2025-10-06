#### Here's another piece move that I call it 'Snare'. This game focus on knight. The classic chess moves apply except:

* If two knights are still in the game, they have a specialty that's called entangle. The entangle happens when two knight in a position where they defend each other; for example one knight in c2 the other in d4; when this happens, if there are any piece, doesn't matter white or black, between those knights (c3 and d3 as in our example), those pieces can't make any move but can be captured by any of the opponent's legal moves. If there're two pieces that're entangled, and if one of them is captured, the other entangled piece has an opportunity to escape the entangle by being able to move one square in a fashion similar to king (when the piece escapes and not captured by any other piece, including knights, it restores its initial ability). If the entangled piece is only one, it can always escape by moving a square like king or move inside the entangle. So, only one piece that's entangled is free to stay in the entangle, and can move to the empty square within it (if it's in c3, then to d3, for instance). If the entangled pieces are from opposite sides, then they can capture one another. Entangled pieces can't capture entangling knights without escaping the entangle. Any entangled king is mated; so, suicides are welcomed!

* If one of knight is captured, then the other one gets a unique ability that's called revengeful. Any piece that captures it is also captured alongside; however, the turn is passed back to opponent. If there're only one knight is on the board, your next promotion can be only knight (no more than two knight is allowed in promotions). After promoting a knight back, regular promotion rules apply again. If you lose all of your knights, you can't promote any other piece (pawns can't be anything else other than being passive pieces if they reach to the other end of the board).

Questions for Clarification:
Entangle geometry: When you say "between" the knights, does this mean:

Only the 2 squares in the rectangular area between them? OR
All squares in a larger zone?
Example: Knights on c2 and d4 → entangle only c3, d3? Or also c4 and d2?
Multiple entangles: Can one player have multiple entangle zones active simultaneously (if they have multiple knight pairs)?

Escape direction: When escaping, can pieces move in ANY direction (like a King's 8 directions), or only away from the entangle?

Passive promoted pawns: When pawns reach the end but can't promote (no knights left), do they:

Stay on the last rank doing nothing?
Get removed from the board?
Block future pawn advances?
Starting knights: Both players start with 2 knights each - is this correct?

Entangle detection: Should the UI visually highlight entangle zones and affected pieces?


1. Yes, only between them, like c3 and d3

2. No. One play can only have two knights during the entire game. If two of them are captured, the player can't promote any other piece including knights.

3. Yes like king in 8 directions. You're outside the entangle when you move to any square other than c2 or d4, for example. In your next turn, your piece behaves as usual.

4. They simply stay where they're but can be captured by your opponent. So, it'd be not practical to move them to the end unless you try to gain time or pass to the turn to your opponent. If you lose both of your knights, there won't be any promotion so they won't block anything else other than themselves.

5. That's correct, yes.

6. Yes please, like we highlight legal moves for the other games


Okay, let me reclarify it:

* Imagine that one knight at d4, the other one at e3, then the entangle zone is being the squares only d3 an e3. by the way, your last fix is pretty good; you've almost fixed it until now except the rule for entangle zone squares