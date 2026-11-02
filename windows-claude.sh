#!/bin/bash

# Lightweight failure visibility without the "one dead clone nukes the run" problem.
# Fires only on failures that `set -e` would trip on (not inside if/||/&& tests).
trap 'echo "[!] Command failed at line $LINENO (exit $?)" >&2' ERR

# BASE SYSTEM
sudo wget https://archive.kali.org/archive-keyring.gpg -O /usr/share/keyrings/kali-archive-keyring.gpg
sudo apt update
if [ ! -d ~/Loot ]; then
    mkdir -p ~/Loot
fi

# DOCKER
sudo apt install -y ca-certificates curl gnupg lsb-release
if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
fi
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    # Debian codename hardcoded to bookworm. lsb_release -cs returns kali-rolling
    # on Kali, which Docker's repo doesn't publish, so don't use it here.
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
      https://download.docker.com/linux/debian bookworm stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# docker-compose-plugin above gives you `docker compose`. This just adds the
# hyphenated `docker-compose` alias for muscle memory. -f makes a bad URL fail
# loudly instead of writing a 404 page to the binary; lowercased uname for the
# real asset names (docker-compose-linux-x86_64).
if [ ! -f /usr/local/bin/docker-compose ]; then
    sudo curl -fL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s | tr 'A-Z' 'a-z')-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

# REQUIREMENTS
export PATH="$HOME/.local/bin:$PATH"
grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc 2>/dev/null \
    || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
if ! command -v go &>/dev/null; then
    sudo apt install -y golang-go
fi

# WINDOWS CRITICAL
uv tool install git+https://github.com/Pennyw0rth/NetExec.git --force
if [ ! -d ~/SpecterOps/Bloodhound ]; then
    mkdir -p ~/SpecterOps/Bloodhound
    wget -O ~/SpecterOps/Bloodhound/bloodhound-cli-linux-amd64.tar.gz https://github.com/SpecterOps/bloodhound-cli/releases/latest/download/bloodhound-cli-linux-amd64.tar.gz
    tar -xvzf ~/SpecterOps/Bloodhound/bloodhound-cli-linux-amd64.tar.gz -C ~/SpecterOps/Bloodhound/
    sudo ~/SpecterOps/Bloodhound/bloodhound-cli install > ~/SpecterOps/Bloodhound/pass.txt
    echo "Initial Password Set To:" && cat ~/SpecterOps/Bloodhound/pass.txt | grep "password:"
else
    sudo ~/SpecterOps/Bloodhound/bloodhound-cli update
fi
# Ghostwriter — fully disabled. Uncomment the whole block to re-enable (the stray
# live `fi` here was a fatal syntax error that aborted the entire rest of the script).
#if [ ! -d ~/SpecterOps/Ghostwriter ]; then
#    mkdir -p ~/SpecterOps/Ghostwriter
#    wget -O ~/SpecterOps/Ghostwriter/ghostwriter-cli-linux-amd64.tar.gz https://github.com/GhostManager/ghostwriter_cli/releases/latest/download/ghostwriter-cli-linux-amd64.tar.gz
#    tar -xvzf ~/SpecterOps/Ghostwriter/ghostwriter-cli-linux-amd64.tar.gz -C ~/SpecterOps/Ghostwriter/
#    sudo ~/SpecterOps/Ghostwriter/ghostwriter-cli install > ~/SpecterOps/Ghostwriter/pass.txt
#    echo "Initial Password Set To:" && cat ~/SpecterOps/Ghostwriter/pass.txt | grep "password:"
#else
#    sudo ~/SpecterOps/Ghostwriter/ghostwriter-cli update
#fi
uv tool install git+https://github.com/dirkjanm/BloodHound.py@bloodhound-ce --force

# WINDOWS UV
uv tool install git+https://github.com/fortra/impacket.git --force
uv tool install git+https://github.com/dirkjanm/ldapdomaindump.git --force
uv tool install git+https://github.com/CravateRouge/bloodyAD.git --force
uv tool install git+https://github.com/aniqfakhrul/powerview.py.git --force
uv tool install git+https://github.com/ly4k/Certipy.git --force
uv tool install git+https://github.com/adityatelange/evil-winrm-py.git --force
uv tool install git+https://github.com/cddmp/enum4linux-ng.git --force
uv tool install git+https://github.com/ShutdownRepo/pywhisker.git --force
uv tool install git+https://github.com/ShawnDEvans/smbmap.git --force

# WINDOWS BUILD
rm -rf ~/WindowsTools/*
mkdir -p ~/WindowsTools/kerbrute
git clone https://github.com/ropnop/kerbrute.git ~/WindowsTools/kerbrute
sudo make -C ~/WindowsTools/kerbrute all
sudo ln -sf ~/WindowsTools/kerbrute/dist/kerbrute_linux_amd64 /usr/local/bin/kerbrute
pip install pipx --break-system-packages
pipx install git+https://github.com/blacklanternsecurity/MANSPIDER
sudo apt install -y ruby ruby-dev libkrb5-dev
sudo gem install evil-winrm
mkdir -p ~/WindowsTools/responder
git clone https://github.com/lgandx/Responder.git ~/WindowsTools/responder
sudo ln -sf ~/WindowsTools/responder/Responder.py /usr/local/bin/responder2
mkdir -p ~/WindowsTools/username-anarchy
git clone https://github.com/urbanadventurer/username-anarchy.git ~/WindowsTools/username-anarchy
sudo ln -sf ~/WindowsTools/username-anarchy/username-anarchy /usr/local/bin/username-anarchy
sudo apt install -y ldap-utils
mkdir -p ~/WindowsTools/windapsearch
git clone https://github.com/ropnop/go-windapsearch.git ~/WindowsTools/windapsearch
cd ~/WindowsTools/windapsearch && go build ./cmd/windapsearch
sudo ln -sf "$(pwd)/windapsearch" /usr/local/bin/windapsearch
mkdir -p ~/WindowsTools/shortscan
git clone https://github.com/bitquark/shortscan.git ~/WindowsTools/shortscan
cd ~/WindowsTools/shortscan/cmd/shortscan && go build
sudo ln -sf "$(pwd)/shortscan" /usr/local/bin/shortscan
mkdir -p ~/WindowsTools/targetedkerberoast
git clone https://github.com/ShutdownRepo/targetedKerberoast.git ~/WindowsTools/targetedkerberoast
sudo ln -sf ~/WindowsTools/targetedkerberoast/targetedKerberoast.py /usr/local/bin/targetedKerberoast.py
git clone https://github.com/dirkjanm/krbrelayx.git ~/WindowsTools/krbrelayx
sudo ln -sf ~/WindowsTools/krbrelayx/krbrelayx.py /usr/local/bin/krbrelayx.py
sudo ln -sf ~/WindowsTools/krbrelayx/dnstool.py /usr/local/bin/dnstool.py
sudo ln -sf ~/WindowsTools/krbrelayx/addspn.py /usr/local/bin/addspn.py
sudo ln -sf ~/WindowsTools/krbrelayx/printerbug.py /usr/local/bin/printerbug.py
mkdir -p ~/WindowsTools/dswalk
git clone https://github.com/Keramas/DS_Walk.git ~/WindowsTools/dswalk
sudo ln -sf ~/WindowsTools/dswalk/ds_walk.py /usr/local/bin/ds_walk.py
sudo ln -sf ~/WindowsTools/dswalk/dsstore.py /usr/local/bin/dsstore.py

# WINDOWS NATIVE TOOLS
rm -rf ~/WindowsNative/*
mkdir -p ~/WindowsNative/mimikatz
git clone https://github.com/ParrotSec/mimikatz.git ~/WindowsNative/mimikatz
mkdir -p ~/WindowsNative/ghostpack
git clone https://github.com/r3motecontrol/Ghostpack-CompiledBinaries.git ~/WindowsNative/ghostpack
mkdir -p ~/WindowsNative/netcat
git clone https://github.com/int0x33/nc.exe.git ~/WindowsNative/netcat
mkdir -p ~/WindowsNative/inveigh
git clone https://github.com/Kevin-Robertson/Inveigh.git ~/WindowsNative/inveigh
mkdir -p ~/WindowsNative/powersploit
git clone https://github.com/PowerShellMafia/PowerSploit.git ~/WindowsNative/powersploit
echo 'findstr /SIM /C:"password" *.txt *.ini *.cfg *.config *.xml' > ~/WindowsNative/CredentialHunting.txt
echo 'findstr /SI /M "password" *.xml *.ini *.txt' >> ~/WindowsNative/CredentialHunting.txt
echo 'findstr /si password *.xml *.ini *.txt *.config' >> ~/WindowsNative/CredentialHunting.txt
echo 'findstr /spin "password" *.*' >> ~/WindowsNative/CredentialHunting.txt
echo 'dir /S /B *pass*.txt == *pass*.xml == *pass*.ini == *cred* == *vnc* == *.config*' >> ~/WindowsNative/CredentialHunting.txt
echo 'where /R C:\ *.config' >> ~/WindowsNative/CredentialHunting.txt
echo 'foreach($user in ((ls C:\users).fullname)){cat "$user\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt" -ErrorAction SilentlyContinue}' >> ~/WindowsNative/CredentialHunting.txt
# Seatbelt https://github.com/GhostPack/Seatbelt (https://github.com/r3motecontrol/Ghostpack-CompiledBinaries)
# winPEAS https://github.com/peass-ng/PEASS-ng/tree/master/winPEAS
# PowerUp https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Privesc/PowerUp.ps1 
# SharpUp https://github.com/GhostPack/SharpUp (https://github.com/r3motecontrol/Ghostpack-CompiledBinaries)
# JAWS https://github.com/411Hall/JAWS
# SessionGopher https://github.com/Arvanaghi/SessionGopher
# Watson https://github.com/rasta-mouse/Watson
# LaZagne https://github.com/AlessandroZ/LaZagne
# Windows Exploit Suggester - Next Generation (WES-NG) https://github.com/bitsadmin/wesng
# Sysinternals https://learn.microsoft.com/en-us/sysinternals/downloads/sysinternals-suite
# PrintSpoofer for SeImpersonate
# Backup Operator Copy NTDS.dit https://github.com/giuliano108/SeBackupPrivilege/tree/master

# REPORTING
sudo apt install -y flameshot
# Needs an X display — guard so it doesn't flail over SSH.
if [ -n "$DISPLAY" ]; then
    flameshot &
    xfconf-query -c xfce4-screenshooter -p /last-save-location -s "$HOME/Loot"
fi

# SYSTEM QoL
rm -rf ~/Monitoring/*
mkdir -p ~/Monitoring/duf
git clone https://github.com/muesli/duf.git ~/Monitoring/duf
go build -C ~/Monitoring/duf
sudo cp ~/Monitoring/duf/duf /usr/local/bin/duf
mkdir -p ~/Monitoring/btop
wget -qO ~/Monitoring/btop/btop.tbz https://github.com/aristocratos/btop/releases/download/v1.4.5/btop-x86_64-linux-musl.tbz
# Strip btop/bin/ and land the binary in /usr/local/bin (on PATH), not /usr/local.
sudo tar xf ~/Monitoring/btop/btop.tbz --strip-components=2 -C /usr/local/bin ./btop/bin/btop
grep -qxF 'cd ~/Loot' ~/.zshrc 2>/dev/null || echo 'cd ~/Loot' >> ~/.zshrc
grep -qxF 'cd ~/Loot' ~/.bashrc 2>/dev/null || echo 'cd ~/Loot' >> ~/.bashrc