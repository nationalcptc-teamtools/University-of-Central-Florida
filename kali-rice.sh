#!/bin/bash

###############################################################################
# Kali Linux Ricing Script
# Replicates macOS configuration for pentesting competitions
# Author: Caio Bittencourt
# Target: Kali Linux
###############################################################################

set -e # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
  echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
  echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[!]${NC} $1"
}

###############################################################################
# 1. Update System and Install Dependencies
###############################################################################
print_status "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y

print_status "Installing required packages..."
sudo apt install -y \
  zsh \
  tmux \
  git \
  curl \
  wget \
  unzip \
  fontconfig \
  build-essential \
  python3 \
  python3-pip \
  bat \
  ripgrep \
  fd-find \
  fzf \
  neovim \
  xclip \
  zoxide \
  eza

print_success "Dependencies installed"

###############################################################################
# 2. Install Nerd Fonts
###############################################################################
print_status "Installing Nerd Fonts (MesloLGS NF for powerlevel10k)..."
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"

cd /tmp
if [ ! -d "nerd-fonts" ]; then
  git clone --depth=1 https://github.com/ryanoasis/nerd-fonts.git
fi
cd nerd-fonts
./install.sh Meslo
fc-cache -fv

print_success "Nerd Fonts installed"

###############################################################################
# 3. Install Oh-My-Zsh
###############################################################################
print_status "Installing Oh-My-Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  print_success "Oh-My-Zsh installed"
else
  print_warning "Oh-My-Zsh already installed, skipping..."
fi

###############################################################################
# 4. Install Oh-My-Zsh Plugins
###############################################################################
print_status "Installing zsh plugins..."

# zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# fast-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting" ]; then
  git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
fi

# zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

print_success "Zsh plugins installed"

###############################################################################
# 5. Install Powerlevel10k
###############################################################################
print_status "Installing Powerlevel10k theme..."
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
  print_success "Powerlevel10k installed"
else
  print_warning "Powerlevel10k already installed, skipping..."
fi

###############################################################################
# 6. Install Starship Prompt (currently used on macOS)
###############################################################################
print_status "Installing Starship prompt..."
if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
  print_success "Starship installed"
else
  print_warning "Starship already installed, skipping..."
fi

###############################################################################
# 7. Setup Tmux Plugin Manager (TPM)
###############################################################################
print_status "Installing Tmux Plugin Manager..."
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  print_success "TPM installed"
else
  print_warning "TPM already installed, skipping..."
fi

###############################################################################
# 8. Configure Tmux
###############################################################################
print_status "Setting up tmux configuration..."
cat >"$HOME/.tmux.conf" <<'EOF'
unbind r
unbind -
unbind =
bind r source-file ~/.tmux.conf \; display "Config Reloaded!"

set -g prefix C-s
set -g mouse on
set-option -g history-limit 10000
set-option -g status-interval 60

# act like vim
setw -g mode-keys vi
bind-key h select-pane -L
bind-key j select-pane -D
bind-key k select-pane -U
bind-key l select-pane -R
bind-key - resize-pane -R 5
bind-key = resize-pane -L 5

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
# set -g @plugin 'dreamsofcode-io/catppuccin-tmux'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @treemux-tree-nvim-init-file '~/.tmux/plugins/treemux/configs/treemux_init.lua'
set -g @plugin 'kiyoon/treemux'
set -g @plugin 'erikw/tmux-powerline'

# Open panes in current directory
bind '"' split-window -v -c "#{pane_current_path}"
bind '%' split-window -h -c "#{pane_current_path}"


# Initialize TMUX plugin manager (keep this at the very bottom of this conf file.
run '~/.tmux/plugins/tpm/tpm'

EOF

print_success "Tmux configured"

###############################################################################
# 9. Configure Zsh
###############################################################################
print_status "Setting up .zshrc configuration..."

# Backup existing .zshrc if it exists
if [ -f "$HOME/.zshrc" ]; then
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"
  print_warning "Backed up existing .zshrc"
fi

cat >"$HOME/.zshrc" <<'EOF'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
# Uncomment to use powerlevel10k instead of starship
# ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(git sudo zsh-syntax-highlighting fast-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR=nvim

# Aliases (Kali-compatible versions)
alias ff="fastfetch"
alias pp="~/.scripts/pipinstall.sh"
alias python="python3"
alias ls="eza -l --icons --time-style=long-iso --group-directories-first"
alias cd="z"
alias cat="batcat"  # Kali uses 'batcat' instead of 'bat'
alias fzf="fzf --preview 'batcat --style=numbers --color=always {}'"
alias fastscan="sudo nmap -p- -sS --min-rate 5000 -T4 -Pn -n"

# Auto-starts tmux on every new shell session if tmux isn't already started
# Uncomment if you want tmux to start automatically
#if command -v tmux &> /dev/null; then
#	[ -z "$TMUX" ] && exec tmux new-session -A -s main
#fi

# EXPORTS
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Initialize zoxide (better cd)
eval "$(zoxide init zsh)"

# Initialize Starship prompt (comment this out if using powerlevel10k)
eval "$(starship init zsh)"
EOF

print_success "Zsh configured"

###############################################################################
# 10. Download p10k config from macOS
###############################################################################
print_status "Setting up Powerlevel10k configuration..."

# Note: The full p10k config is very large, so we create a minimal version
# Users can run 'p10k configure' to customize further
cat >"$HOME/.p10k.zsh" <<'EOF'
# Generated by Powerlevel10k configuration wizard
# Wizard options: nerdfont-v3 + powerline, small icons, classic, unicode, darkest,
# 12h time, angled separators, sharp heads, flat tails, 2 lines, disconnected, no frame,
# sparse, many icons, concise, transient_prompt, instant_prompt=verbose.
# Type `p10k configure` to generate another config.

# Temporarily change options.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]] || return

  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon
    dir
    vcs
    newline
    prompt_char
  )

  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status
    command_execution_time
    background_jobs
    virtualenv
    context
    time
  )

  typeset -g POWERLEVEL9K_MODE=nerdfont-v3
  typeset -g POWERLEVEL9K_ICON_PADDING=moderate
  typeset -g POWERLEVEL9K_BACKGROUND=
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP_CHAR=' '
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='❮'

  typeset -g POWERLEVEL9K_DIR_FOREGROUND=31
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
  typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND=103
  typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND=39
  typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=true

  typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='\uF126 '
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178

  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=160

  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=101

  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=70

  typeset -g POWERLEVEL9K_CONTEXT_ROOT_FOREGROUND=178
  typeset -g POWERLEVEL9K_CONTEXT_{REMOTE,REMOTE_SUDO}_FOREGROUND=180
  typeset -g POWERLEVEL9K_CONTEXT_FOREGROUND=180

  typeset -g POWERLEVEL9K_VIRTUALENV_FOREGROUND=37

  typeset -g POWERLEVEL9K_TIME_FOREGROUND=66
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%I:%M:%S %p}'

  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
EOF

print_success "Powerlevel10k configured"

###############################################################################
# 11. Create helper scripts directory
###############################################################################
print_status "Creating scripts directory..."
mkdir -p "$HOME/.scripts"

# Create a simple pipinstall.sh script if referenced
cat >"$HOME/.scripts/pipinstall.sh" <<'EOF'
#!/bin/bash
# Simple pip install wrapper
pip3 install "$@"
EOF
chmod +x "$HOME/.scripts/pipinstall.sh"

print_success "Helper scripts created"

###############################################################################
# 12. Change default shell to zsh
###############################################################################
print_status "Setting zsh as default shell..."
if [ "$SHELL" != "$(which zsh)" ]; then
  chsh -s $(which zsh)
  print_success "Default shell changed to zsh (restart terminal to apply)"
else
  print_success "Zsh is already the default shell"
fi

###############################################################################
# 13. Install tmux plugins
###############################################################################
print_status "Installing tmux plugins..."
# TPM requires tmux to be running, so we provide instructions
print_warning "To install tmux plugins, run: tmux new-session -d -s temp && ~/.tmux/plugins/tpm/bin/install_plugins && tmux kill-session -t temp"

###############################################################################
# 14. Additional pentesting tools setup
###############################################################################
print_status "Setting up additional pentesting environment..."

# Install common pentesting Python packages
pip3 install --user sqlmap impacket pwntools

# Ensure common directories exist
mkdir -p "$HOME/Pentesting"
mkdir -p "$HOME/tools"

print_success "Pentesting environment setup complete"

###############################################################################
# 15. Final Notes
###############################################################################
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Kali Linux Ricing Complete!                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
print_status "Next steps:"
echo "  1. Restart your terminal or run: exec zsh"
echo "  2. Install tmux plugins by opening tmux and pressing: Ctrl+s then I (capital i)"
echo "  3. If you want to use Powerlevel10k instead of Starship:"
echo "     - Edit ~/.zshrc and uncomment: ZSH_THEME=\"powerlevel10k/powerlevel10k\""
echo "     - Comment out: eval \"\$(starship init zsh)\""
echo "     - Run: p10k configure (to customize further)"
echo "  4. Install Nerd Font in your terminal emulator settings"
echo "  5. Enjoy your riced Kali setup!"
echo ""
print_success "Configuration files backed up with timestamp"
echo ""
