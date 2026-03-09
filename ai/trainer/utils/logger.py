"""
Training Logger - Pretty Console Output for ChessRecast AI Training
════════════════════════════════════════════════════════════════════
Rich emoji-decorated, box-drawn, color-coded training output.
Replaces raw print() calls with structured, readable logging.
"""
import sys
import time
import unicodedata
from typing import Optional, Dict, Any


# ─── Box Drawing Characters ─────────────────────────────────────
TOP_LEFT     = "╔"
TOP_RIGHT    = "╗"
BOT_LEFT     = "╚"
BOT_RIGHT    = "╝"
HORIZONTAL   = "═"
VERTICAL     = "║"
T_LEFT       = "╠"
T_RIGHT      = "╣"
LIGHT_H      = "─"
LIGHT_V      = "│"
LIGHT_TL     = "┌"
LIGHT_TR     = "┐"
LIGHT_BL     = "└"
LIGHT_BR     = "┘"
LIGHT_T_LEFT = "├"
LIGHT_T_RIGHT= "┤"
DOT          = "•"
ARROW        = "→"
CHECK        = "✓"
CROSS        = "✗"
SPARKLE      = "✦"

# ─── ANSI Colors ────────────────────────────────────────────────
# These work in Docker logs and most modern terminals
RESET   = "\033[0m"
BOLD    = "\033[1m"
DIM     = "\033[2m"
RED     = "\033[91m"
GREEN   = "\033[92m"
YELLOW  = "\033[93m"
BLUE    = "\033[94m"
MAGENTA = "\033[95m"
CYAN    = "\033[96m"
WHITE   = "\033[97m"
GRAY    = "\033[90m"

# ─── Mod Emojis ───────────────────────────────────────────────
MOD_EMOJI = {
    "mercenary":    "⚔️",
    "heir":         "👑",
    "truce":        "🤝",
    "friendlyFire": "🔥",
    "kingsBattle":  "⚔️👑",
    "saveTheQueen": "🛡️",
    "succession":   "🏰",
    "classic":      "♟️",
}

WIDTH = 60


def _line(char=HORIZONTAL, width=WIDTH):
    return char * width


def _box_top(width=WIDTH):
    return f"{TOP_LEFT}{_line(width=width)}{TOP_RIGHT}"


def _box_bot(width=WIDTH):
    return f"{BOT_LEFT}{_line(width=width)}{BOT_RIGHT}"


def _box_mid(width=WIDTH):
    return f"{T_LEFT}{_line(width=width)}{T_RIGHT}"


def _visual_len(text):
    """Terminal display width of text, handling emoji and wide characters."""
    import re
    # Strip ANSI escape codes first
    clean = re.sub(r'\033\[[0-9;]*m', '', text)
    w = 0
    last_w = 0
    for ch in clean:
        cp = ord(ch)
        # VS16 (emoji presentation selector): upgrades preceding narrow char to wide
        if cp == 0xFE0F:
            if last_w == 1:
                w += 1
            last_w = 0
            continue
        # Zero-width: ZWJ, combining marks
        if cp == 0x200D or unicodedata.category(ch).startswith('M'):
            last_w = 0
            continue
        # Wide: supplementary emoji planes, CJK, fullwidth
        if cp >= 0x1F000 or unicodedata.east_asian_width(ch) in ('W', 'F'):
            w += 2
            last_w = 2
        else:
            w += 1
            last_w = 1
    return w


def _box_row(text, width=WIDTH):
    # Strip ANSI codes for visual length calculation
    import re
    clean = re.sub(r'\033\[[0-9;]*m', '', text)
    # -1 accounts for the leading space after ║
    padding = width - 1 - _visual_len(clean)
    if padding < 0:
        padding = 0
    return f"{VERTICAL} {text}{' ' * padding}{VERTICAL}"


def _light_line(width=WIDTH):
    return f"  {LIGHT_H * width}"


class TrainingLogger:
    """Structured, pretty-printed training output."""

    def __init__(self, mode: str = "mercenary"):
        self.mode = mode
        self.emoji = MOD_EMOJI.get(mode, "🎯")
        self._game_start: Optional[float] = None
        self._iter_start: Optional[float] = None
        self._train_start: Optional[float] = None

    def _p(self, *args, **kwargs):
        print(*args, flush=True, **kwargs)

    # ═══════════════════════════════════════════════════════════
    #  Banner & Headers
    # ═══════════════════════════════════════════════════════════

    def banner(self, title: str, subtitle: str = "", test_mode: bool = False):
        """Print the big startup banner."""
        self._train_start = time.time()
        mode_label = f"{self.emoji}  {self.mode.upper()} MOD"
        status = f"{'TEST / DEMO' if test_mode else title}"

        self._p(f"\n{CYAN}{_box_top()}{RESET}")
        self._p(f"{CYAN}{_box_row(f'{BOLD}ChessRecast AI Trainer{RESET}{CYAN}')}{RESET}")
        self._p(f"{CYAN}{_box_row(f'{mode_label}')}{RESET}")
        self._p(f"{CYAN}{_box_mid()}{RESET}")
        self._p(f"{CYAN}{_box_row(f'{YELLOW}{status}{RESET}{CYAN}')}{RESET}")
        if subtitle:
            self._p(f"{CYAN}{_box_row(f'{DIM}{subtitle}{RESET}{CYAN}')}{RESET}")
        self._p(f"{CYAN}{_box_bot()}{RESET}")

    def section(self, emoji: str, title: str):
        """Print a section header."""
        header = f"{emoji}  {title}"
        self._p(f"\n{BOLD}{header}{RESET}")
        self._p(f"  {GRAY}{LIGHT_H * _visual_len(header)}{RESET}")

    def subsection(self, title: str):
        """Print a lighter subsection."""
        self._p(f"  {CYAN}{SPARKLE}{RESET} {title}")

    # ═══════════════════════════════════════════════════════════
    #  GPU / Device Info
    # ═══════════════════════════════════════════════════════════

    def device_info(self, device: str, gpu_name: str = "", vram_gb: float = 0):
        self.section("🖥️", "Device")
        if device == "cuda":
            self._p(f"  {GREEN}{CHECK}{RESET} GPU: {BOLD}{gpu_name}{RESET}")
            self._p(f"  {GREEN}{CHECK}{RESET} VRAM: {vram_gb:.1f} GB")
        else:
            self._p(f"  {YELLOW}⚠{RESET}  CPU (no GPU — slower)")

    def gpu_optimizations(self, items: list[str]):
        self.section("🔥", "GPU Optimizations")
        for item in items:
            self._p(f"  {GREEN}{CHECK}{RESET} {item}")

    # ═══════════════════════════════════════════════════════════
    #  Configuration
    # ═══════════════════════════════════════════════════════════

    def config(self, params: Dict[str, Any], label: str = "Training Configuration"):
        self.section("⚡", label)
        max_key_len = max(len(str(k)) for k in params.keys())
        for key, value in params.items():
            padded = str(key).ljust(max_key_len)
            self._p(f"    {padded}  {CYAN}{value}{RESET}")

    # ═══════════════════════════════════════════════════════════
    #  Network
    # ═══════════════════════════════════════════════════════════

    def network_info(self, channels: int, res_blocks: int, params: int, device: str):
        label = "Large" if channels >= 128 else "Small"
        self.section("🧠", f"Neural Network ({label})")
        self._p(f"    Channels:    {CYAN}{channels}{RESET}")
        self._p(f"    Res Blocks:  {CYAN}{res_blocks}{RESET}")
        self._p(f"    Parameters:  {CYAN}{params:,}{RESET}")
        self._p(f"    Device:      {CYAN}{device.upper()}{RESET}")

    # ═══════════════════════════════════════════════════════════
    #  Iteration
    # ═══════════════════════════════════════════════════════════

    def iteration_start(self, iteration: int, total: int, gpu_util: int = -1):
        self._iter_start = time.time()
        gpu_str = f"  {GRAY}[GPU: {gpu_util}%]{RESET}" if gpu_util >= 0 else ""

        self._p(f"\n{CYAN}{'━' * WIDTH}{RESET}")
        self._p(f"  {self.emoji}  {BOLD}Iteration {iteration}/{total}{RESET}{gpu_str}")
        self._p(f"{CYAN}{'━' * WIDTH}{RESET}")

    def self_play_header(self, games: int, mcts_sims: int, temperature: float):
        self._p(f"\n  🎲 {BOLD}Self-Play{RESET}  "
                f"{GRAY}{DOT}{RESET} {games} games  "
                f"{GRAY}{DOT}{RESET} MCTS: {mcts_sims}  "
                f"{GRAY}{DOT}{RESET} T={temperature:.2f}")

    def game_result(self, game_num: int, total_games: int, moves: int, elapsed: float):
        if moves > 0:
            speed = elapsed / moves
            bar_pct = game_num / total_games
            bar_filled = int(bar_pct * 20)
            bar = f"{GREEN}{'█' * bar_filled}{GRAY}{'░' * (20 - bar_filled)}{RESET}"
            self._p(f"  {bar} {GRAY}{game_num:>3}/{total_games}{RESET}  "
                    f"{moves:>3} moves  {elapsed:.1f}s  "
                    f"{DIM}({speed:.2f}s/move){RESET}")
        else:
            self._p(f"  {YELLOW}⚠{RESET}  Game {game_num}: 0 moves")

    def games_progress(self, game_num: int, total_games: int, positions: int,
                       w: int, d: int, b: int, gpu_util: int = -1):
        gpu_str = f"  {GRAY}GPU:{gpu_util}%{RESET}" if gpu_util >= 0 else ""
        self._p(f"  {GRAY}{LIGHT_T_LEFT}{LIGHT_H}{RESET} "
                f"Positions: {CYAN}{positions:,}{RESET}  "
                f"W:{GREEN}{w}{RESET} D:{YELLOW}{d}{RESET} B:{RED}{b}{RESET}"
                f"{gpu_str}")

    def self_play_summary(self, positions: int, w: int, d: int, b: int, recorded: int = 0):
        self._p(f"\n  {GREEN}{CHECK}{RESET} Generated {BOLD}{positions:,}{RESET} training positions")
        self._p(f"  {GREEN}{CHECK}{RESET} Results:  "
                f"W:{GREEN}{w}{RESET}  D:{YELLOW}{d}{RESET}  B:{RED}{b}{RESET}")
        if recorded > 0:
            self._p(f"  {GREEN}{CHECK}{RESET} Saved {recorded} games for viewer")

    # ═══════════════════════════════════════════════════════════
    #  Training Epochs
    # ═══════════════════════════════════════════════════════════

    def training_header(self, epochs: int, batch_size: int):
        self._p(f"\n  🎓 {BOLD}Training{RESET}  "
                f"{GRAY}{DOT}{RESET} {epochs} epochs  "
                f"{GRAY}{DOT}{RESET} batch={batch_size}")

    def epoch_result(self, epoch: int, total_epochs: int,
                     total_loss: float, policy_loss: float, value_loss: float):
        bar_pct = epoch / total_epochs
        bar_filled = int(bar_pct * 15)
        bar = f"{MAGENTA}{'█' * bar_filled}{GRAY}{'░' * (15 - bar_filled)}{RESET}"
        self._p(f"  {bar} Epoch {epoch:>2}/{total_epochs}  "
                f"Loss={YELLOW}{total_loss:.4f}{RESET} "
                f"({DIM}P={policy_loss:.4f} V={value_loss:.4f}{RESET})")

    # ═══════════════════════════════════════════════════════════
    #  Iteration Summary
    # ═══════════════════════════════════════════════════════════

    def iteration_summary(self, iteration: int, total: int,
                          loss: float, lr: float, checkpoint: str = ""):
        iter_time = time.time() - self._iter_start if self._iter_start else 0
        total_time = time.time() - self._train_start if self._train_start else 0
        eta = (total_time / iteration) * (total - iteration) if iteration > 0 else 0

        self._p(f"\n  📊 {BOLD}Summary{RESET}")
        self._p(f"    Loss:     {YELLOW}{loss:.4f}{RESET}")
        self._p(f"    LR:       {CYAN}{lr:.6f}{RESET}")
        self._p(f"    Time:     {iter_time:.1f}s")
        self._p(f"    ETA:      {eta/3600:.1f}h  "
                f"{DIM}({total_time/3600:.1f}h elapsed){RESET}")
        if checkpoint:
            self._p(f"    {GREEN}{CHECK}{RESET} Checkpoint: {checkpoint}")

    # ═══════════════════════════════════════════════════════════
    #  Final / Completion
    # ═══════════════════════════════════════════════════════════

    def save_final(self, model_path: str, metrics_path: str):
        self._p(f"\n{CYAN}{_box_top()}{RESET}")
        self._p(f"{CYAN}{_box_row(f'💾 {BOLD}SAVING FINAL MODEL{RESET}{CYAN}')}{RESET}")
        self._p(f"{CYAN}{_box_bot()}{RESET}")
        self._p(f"  {GREEN}{CHECK}{RESET} Model:   {model_path}")
        self._p(f"  {GREEN}{CHECK}{RESET} Metrics: {metrics_path}")

    def training_complete(self, total_hours: float):
        self._p(f"\n{GREEN}{_box_top()}{RESET}")
        self._p(f"{GREEN}{_box_row(f'🏁 {BOLD}TRAINING COMPLETE{RESET}{GREEN}')}{RESET}")
        self._p(f"{GREEN}{_box_row(f'   Total time: {total_hours:.2f} hours')}{RESET}")
        self._p(f"{GREEN}{_box_row(f'   {self.emoji}  {self.mode.upper()} mod')}{RESET}")
        self._p(f"{GREEN}{_box_bot()}{RESET}")

    # ═══════════════════════════════════════════════════════════
    #  Test Mod
    # ═══════════════════════════════════════════════════════════

    def test_mode_banner(self, move_delay: float):
        self._p(f"\n{YELLOW}{_box_top()}{RESET}")
        self._p(f"{YELLOW}{_box_row(f'{self.emoji}  {BOLD}TEST MOD{RESET}{YELLOW}  {GRAY}Playing random games{RESET}{YELLOW}')}{RESET}")
        self._p(f"{YELLOW}{_box_row(f'   Move delay: {move_delay}s  {GRAY}{DOT}  Ctrl+C to stop{RESET}{YELLOW}')}{RESET}")
        self._p(f"{YELLOW}{_box_bot()}{RESET}")

    def test_game_start(self, game_num: int, fen: str):
        self._game_start = time.time()
        self._p(f"\n  {self.emoji}  {BOLD}Game {game_num}{RESET}")
        self._p(f"    FEN: {DIM}{fen}{RESET}")

    def test_move(self, move_num: int, uci: str, turn: str):
        color = GREEN if turn == "white" else BLUE
        self._p(f"    {color}{DOT}{RESET} {move_num:>3}. {uci}")

    def training_move(self, move_num: int, uci: str, turn: str, value: float = 0.0):
        """Log a single move during training self-play."""
        color = GREEN if turn == "white" else BLUE
        val_str = f"  {DIM}v={value:+.2f}{RESET}" if value != 0.0 else ""
        self._p(f"    {color}{DOT}{RESET} {move_num:>3}. {uci}{val_str}")

    def training_game_end(self, game_num: int, total_games: int, result: str, moves: int):
        """Log the outcome of a training self-play game."""
        RESULT_DISPLAY = {
            '1-0':     f"{GREEN}White wins{RESET}",
            '0-1':     f"{BLUE}Black wins{RESET}",
            '1/2-1/2': f"{YELLOW}Draw{RESET}",
        }
        label = RESULT_DISPLAY.get(result, f"{DIM}{result}{RESET}")
        self._p(f"    {ARROW} Game {game_num}/{total_games}  {label}  ({moves} moves)")

    def test_game_end(self, game_num: int, result: str, move_count: int):
        elapsed = time.time() - self._game_start if self._game_start else 0
        if result == "ERROR":
            self._p(f"  {RED}{CROSS}{RESET} Game {game_num} {RED}STOPPED{RESET} "
                    f"({move_count} moves, {elapsed:.1f}s)")
        else:
            self._p(f"  {GREEN}{CHECK}{RESET} Game {game_num} → {BOLD}{result}{RESET} "
                    f"({move_count} moves, {elapsed:.1f}s)")

    def validation_error(self, move_num: int, uci: str, error: str):
        self._p(f"\n  {RED}🛑 VALIDATION ERROR{RESET}")
        self._p(f"    Move #{move_num}: {uci}")
        self._p(f"    {RED}{error}{RESET}")

    def critical_error(self, msg: str, fen: str = ""):
        self._p(f"\n  {RED}🚨 CRITICAL: {msg}{RESET}")
        if fen:
            self._p(f"    FEN: {DIM}{fen}{RESET}")

    def info(self, msg: str):
        self._p(f"  {GREEN}{CHECK}{RESET} {msg}")

    def warn(self, msg: str):
        self._p(f"  {YELLOW}⚠{RESET}  {msg}")

    def status(self, msg: str):
        self._p(f"  {GRAY}{DOT}{RESET}  {msg}")
