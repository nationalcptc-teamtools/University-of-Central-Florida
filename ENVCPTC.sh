#!/bin/bash
#===============================================================================
# SCRIPT NAME   : ENVCPTC.sh
# DESCRIPTION   : Builds an offensive toolkit tailored to Windows
# AUTHOR        : 3mi55ary
# DATE          : 2025-10-26
# VERSION       : 1.0
# USAGE         : ./ENVCPTC.sh
# NOTES         : Must run "git clone" from "~/" and then run ./ENVCPTC.sh without sudo (sudo is handled by the script when needed).
# NOTES         : Tested on Latest Release of Kali Linux.
#===============================================================================
#===============================================================================
# System Basics ================================================================
#===============================================================================
# Create Report
echo "[+] Report Created" > ~/Report.txt

# Generate Quick Commands Guide
echo "=== QUICK COMMANDS GUIDE ===" > ~/Commands.txt
echo "[+] Quick Commands Guide Created" > ~/Report.txt

if [ ! -d ~/Loot ]; then
    mkdir -p ~/Loot
    echo "[+] Loot Directory Added -- Start filling it!" >> ~/Report.txt
fi

#===============================================================================
# Requirements =================================================================
#===============================================================================
# Install UV
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
if ! command -v uv &>/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo "[+] UV Installed" >> ~/Report.txt
fi

#===============================================================================
# WINDOWS TOOLING (UV) =========================================================
#===============================================================================
# https://wadcoms.github.io/
if [ ! -d ~/WindowsTools ]; then   
    # NetExec
    uv tool install git+https://github.com/Pennyw0rth/NetExec.git --force
    echo "NXC: nxc <service> -u '' -p '' (-M <module>)" >> ~/Commands.txt
    echo "[+] NXC Deployed" >> ~/Report.txt
    
    # Bloodhound-CE Ingestor (Python Based) (bloodhound-ce-python -c All -d yourdomain.local -u username -p password -ns dnsserver)
    uv tool install git+https://github.com/dirkjanm/BloodHound.py@bloodhound-ce --force
    echo "Bloodhound-CE Ingestor: bloodhound-ce-python -c All -d yourdomain.local -u username -p password -ns dnsserver" >> ~/Commands.txt
    echo "[+] Bloodhound-CE Ingestor Deployed" >> ~/Report.txt
    
    # Impacket
    uv tool install git+https://github.com/fortra/impacket.git --force
    echo "IMPACKET: impacket-<option> domain/username:'password'@<IP/Hostname>" >> ~/Commands.txt
    echo "[+] Impacket Deployed" >> ~/Report.txt
    
    # ldapdomaindump (sudo python3 ldapdomaindump.py ldap://DC -u 'DOMAIN\user' -p 'Password')
    # If throwing MD4 crypt error (sudo python3 /usr/local/bin/ldapdomaindump ldap://DC -u 'DOMAIN\user' -p 'Password')
    uv tool install git+https://github.com/dirkjanm/ldapdomaindump.git --force
    echo "LDAPDOMAINDUMP: sudo python3 /usr/local/bin/ldapdomaindump ldap://<DC-IP> -u 'DOMAIN\user' -p 'Password'" >> ~/Commands.txt
    echo "[+] ldapdomaindump Deployed" >> ~/Report.txt
    
    # BloodyAD
    uv tool install git+https://github.com/CravateRouge/bloodyAD.git --force
    echo "[+] BloodyAD Deployed" >> ~/Report.txt
    
    # Certipy-AD
    uv tool install git+https://github.com/ly4k/Certipy.git --force
    echo "[+] Certipy Deployed" >> ~/Report.txt
    
    # Evil-WinRM-py
    uv tool install git+https://github.com/adityatelange/evil-winrm-py.git --force
    echo "[+] Evil-WinRM-py Deployed" >> ~/Report.txt
    
    # enum4linux
    uv tool install git+https://github.com/cddmp/enum4linux-ng.git --force
    echo "[+] enum4linux Deployed" >> ~/Report.txt

    # pyWhisker
    uv tool install git+https://github.com/ShutdownRepo/pywhisker.git --force
    echo "[+] pyWhisker Deployed" >> ~/Report.txt
    
    # smbmap
    uv tool install git+https://github.com/ShawnDEvans/smbmap.git --force
    echo "[+] SMBmap Deployed" >> ~/Report.txt

    #===============================================================================
    # WINDOWS TOOLING (Make/Build/Link) ============================================
    #===============================================================================
    # Updates Kali GPG keyring
    sudo wget https://archive.kali.org/archive-keyring.gpg -O /usr/share/keyrings/kali-archive-keyring.gpg
    sudo apt update
    echo "[+] GPG Keyring Updated" >> ~/Report.txt

    # Install Golang
    if ! command -v go &>/dev/null; then
        sudo apt install -y golang-go
        echo "[+] Golang Installed" >> ~/Report.txt
    fi

    # kerbrute (sudo kerbrute userenum -d DOMAIN.local --dc IP users.txt | Create users list from ldapdomaindump | Hashcat mode 18200)
    mkdir -p ~/WindowsTools/kerbrute
    git clone https://github.com/ropnop/kerbrute.git ~/WindowsTools/kerbrute
    sudo make -C ~/WindowsTools/kerbrute all
    sudo ln -sf ~/WindowsTools/kerbrute/dist/kerbrute_linux_amd64 /usr/local/bin/kerbrute
    echo "KERBRUTE: sudo kerbrute userenum -d DOMAIN.local --dc IP users.txt" >> ~/Commands.txt
    echo "[+] Kerbrute Deployed" >> ~/Report.txt
        
    # Evil-WinRM
    sudo apt install -y ruby ruby-dev libkrb5-dev
    sudo gem install evil-winrm
    echo "[+] Evil-WinRM Deployed" >> ~/Report.txt

    # responder
    mkdir -p ~/WindowsTools/responder
    git clone https://github.com/lgandx/Responder.git ~/WindowsTools/responder
    sudo ln -s ~/WindowsTools/responder/Responder.py /usr/local/bin/responder2
    echo "RESPONDER: sudo responder2 -i eth0" >> ~/Commands.txt
    echo "[+] Responder Deployed" >> ~/Report.txt

    # ldapsearch
    sudo apt install -y ldap-utils
    echo "[+] LDAPsearch Deployed" >> ~/Report.txt
    
    # windapsearch
    mkdir -p ~/WindowsTools/windapsearch
    git clone https://github.com/ropnop/go-windapsearch.git ~/WindowsTools/windapsearch
    cd ~/WindowsTools/windapsearch && go build ./cmd/windapsearch
    sudo ln -sf "$(pwd)/windapsearch" /usr/local/bin/windapsearch
    echo "[+] Windapsearch Deployed" >> ~/Report.txt
    
    # shortscan
    mkdir -p ~/WindowsTools/shortscan
    git clone https://github.com/bitquark/shortscan.git ~/WindowsTools/shortscan
    cd ~/WindowsTools/shortscan/cmd/shortscan && go build
    sudo ln -sf "$(pwd)/shortscan" /usr/local/bin/shortscan
    echo "[+] Shortscan Deployed" >> ~/Report.txt

    # targetedkerberoast (Abuses ACLs to Add an SPN and Kerberoast)
    mkdir -p ~/WindowsTools/targetedkerberoast
    git clone https://github.com/ShutdownRepo/targetedKerberoast.git ~/WindowsTools/targetedkerberoast
    sudo ln -s ~/WindowsTools/targetedkerberoast/targetedKerberoast.py /usr/local/bin/targetedKerberoast.py
    echo "[+] TargetedKerberoast Deployed" >> ~/Report.txt
    
    # krbrelayx
    git clone https://github.com/dirkjanm/krbrelayx.git ~/WindowsTools/krbrelayx
    sudo ln -s ~/WindowsTools/krbrelayx/krbrelayx.py /usr/local/bin/krbrelayx.py
    sudo ln -s ~/WindowsTools/krbrelayx/dnstool.py /usr/local/bin/dnstool.py
    sudo ln -s ~/WindowsTools/krbrelayx/addspn.py /usr/local/bin/addspn.py
    sudo ln -s ~/WindowsTools/krbrelayx/printerbug.py /usr/local/bin/printerbug.py
    echo "[+] Krbrelayx Deployed" >> ~/Report.txt
    
    # ds_walk
    mkdir -p ~/WindowsTools/dswalk
    git clone https://github.com/Keramas/DS_Walk.git ~/WindowsTools/dswalk
    sudo ln -s ~/WindowsTools/dswalk/ds_walk.py /usr/local/bin/ds_walk.py
    sudo ln -s ~/WindowsTools/dswalk/dsstore.py /usr/local/bin/dsstore.py
    echo "[+] DS_Walk Deployed" >> ~/Report.txt
fi

#===============================================================================
# WINDOWS TOOLING (Transfer to Compromised Host) ===============================
#===============================================================================
if [ ! -d ~/WindowsNative ]; then
    # mimikatz
    mkdir -p ~/WindowsNative/mimikatz
    git clone https://github.com/ParrotSec/mimikatz.git ~/WindowsNative/mimikatz
    echo "[+] Mimikatz Added" >> ~/Report.txt

    # netcat
    mkdir -p ~/WindowsNative/netcat
    git clone https://github.com/int0x33/nc.exe.git ~/WindowsNative/netcat
    echo "[+] Netcat Added" >> ~/Report.txt
    
    # inveigh
    mkdir -p ~/WindowsNative/inveigh
    git clone https://github.com/Kevin-Robertson/Inveigh.git ~/WindowsNative/inveigh
    echo "[+] Inveigh Added" >> ~/Report.txt
    
    # powersploit (RECON -> Then Upload PowerView.ps1)
    mkdir -p ~/WindowsNative/powersploit
    git clone https://github.com/PowerShellMafia/PowerSploit.git ~/WindowsNative/powersploit
    echo "[+] PowerSploit Added" >> ~/Report.txt
    
    # Manual Credential Hunting
    # echo "" >> ~/WindowsNative/CredentialHunting.txt
    echo 'https://wadcoms.github.io/' > ~/WindowsNative/CredentialHunting.txt
    echo 'findstr /SIM /C:"password" *.txt *.ini *.cfg *.config *.xml' >> ~/WindowsNative/CredentialHunting.txt
    echo 'findstr /SI /M "password" *.xml *.ini *.txt' >> ~/WindowsNative/CredentialHunting.txt
    echo 'findstr /si password *.xml *.ini *.txt *.config' >> ~/WindowsNative/CredentialHunting.txt
    echo 'findstr /spin "password" *.*' >> ~/WindowsNative/CredentialHunting.txt
    echo 'dir /S /B *pass*.txt == *pass*.xml == *pass*.ini == *cred* == *vnc* == *.config*' >> ~/WindowsNative/CredentialHunting.txt
    echo 'where /R C:\ *.config' >> ~/WindowsNative/CredentialHunting.txt
    echo 'foreach($user in ((ls C:\users).fullname)){cat "$user\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt" -ErrorAction SilentlyContinue}' >> ~/WindowsNative/CredentialHunting.txt
    echo "[+] CredentialHunting Support File Deployed" >> ~/Report.txt
fi

#===============================================================================
# PIVOTING TOOLING =============================================================
#===============================================================================
if [ ! -d ~/PivotingTools ]; then
    # ligolo
    mkdir -p ~/PivotingTools/ligolo
    wget -P ~/PivotingTools/ligolo https://github.com/nicocha30/ligolo-ng/releases/download/v0.8.2/ligolo-ng_proxy_0.8.2_linux_amd64.tar.gz
    sudo rm ~/PivotingTools/ligolo/LICENSE
    sudo rm ~/PivotingTools/ligolo/README.md
    wget -P ~/PivotingTools/ligolo https://github.com/nicocha30/ligolo-ng/releases/download/v0.8.2/ligolo-ng_agent_0.8.2_linux_amd64.tar.gz
    sudo rm ~/PivotingTools/ligolo/LICENSE
    sudo rm ~/PivotingTools/ligolo/README.md
    wget -P ~/PivotingTools/ligolo https://github.com/nicocha30/ligolo-ng/releases/download/v0.8.2/ligolo-ng_agent_0.8.2_windows_amd64.zip
    tar -xvzf ~/PivotingTools/ligolo/ligolo-ng_proxy_0.8.2_linux_amd64.tar.gz -C ~/PivotingTools/ligolo
    tar -xvzf ~/PivotingTools/ligolo/ligolo-ng_agent_0.8.2_linux_amd64.tar.gz -C ~/PivotingTools/ligolo
    unzip -q ~/PivotingTools/ligolo/ligolo-ng_agent_0.8.2_windows_amd64.zip -d ~/PivotingTools/ligolo
    mkdir -p ~/PivotingTools/ligolo/storage
    sudo mv ~/PivotingTools/ligolo/ligolo-ng_proxy_0.8.2_linux_amd64.tar.gz ~/PivotingTools/ligolo/ligolo-ng_agent_0.8.2_linux_amd64.tar.gz ~/PivotingTools/ligolo/ligolo-ng_agent_0.8.2_windows_amd64.zip ~/PivotingTools/ligolo/storage
    echo "[+] Ligolo Deployed" >> ~/Report.txt

    # chisel
    mkdir -p ~/PivotingTools/chisel
    curl https://i.jpillora.com/chisel! | bash
    wget -P ~/PivotingTools/chisel https://github.com/jpillora/chisel/releases/download/v1.11.3/chisel_1.11.3_windows_amd64.zip
    unzip -q ~/PivotingTools/chisel/chisel_1.11.3_windows_amd64.zip -d ~/PivotingTools/chisel
    wget -P ~/PivotingTools/chisel https://github.com/jpillora/chisel/releases/download/v1.11.3/chisel_1.11.3_linux_amd64.gz
    gunzip -c ~/PivotingTools/chisel/chisel_1.11.3_linux_amd64.gz > ~/PivotingTools/chisel/chisel_1.11.3_linux_amd64
    echo "[+] Chisel Deployed" >> ~/Report.txt
fi

#===============================================================================
# Screenshots ==================================================================
#===============================================================================
# Install and Configure Flameshot for Instant Usage
sudo apt install -y flameshot
flameshot &
echo "[+] Flameshot Deployed" >> ~/Report.txt

# Set XFCE's default screenshot save path (BACKUP)
xfconf-query -c xfce4-screenshooter \
    -p /last-save-location \
    -s "$HOME/Loot"
echo "[+] XFCE Default Path Changed to ~/Loot" >> ~/Report.txt

#===============================================================================
# System QoL ===================================================================
#===============================================================================
if [ ! -d ~/Monitoring ]; then
    # DUF
    mkdir -p ~/Monitoring/duf
    git clone https://github.com/muesli/duf.git ~/Monitoring/duf
    go build -C ~/Monitoring/duf
    sudo cp ~/Monitoring/duf/duf /usr/local/bin/duf
    echo "[+] DUF Deployed" >> ~/Report.txt

    # btop
    mkdir -p ~/Monitoring/btop
    wget -qO ~/Monitoring/btop/btop.tbz https://github.com/aristocratos/btop/releases/download/v1.4.5/btop-x86_64-linux-musl.tbz
    sudo tar xf ~/Monitoring/btop/btop.tbz --strip-components=2 -C /usr/local ./btop/bin/btop
    echo "[+] Btop Deployed" >> ~/Report.txt

    # Various Quality of Life short scripts
    mkdir -p ~/Monitoring/qol
    # Creds Script (stores found credentials in 'username':'password' format and puts them in ~/Loot/creds.txt)
    # Write the PASSWORDS script line-by-line
    echo "#!/bin/bash" > ~/Monitoring/qol/StoreCred.sh
    echo "read -p \"Enter username: \" username" >> ~/Monitoring/qol/StoreCred.sh
    echo "read -p \"Enter password: \" password" >> ~/Monitoring/qol/StoreCred.sh
    echo "echo" >> ~/Monitoring/qol/StoreCred.sh
    echo "# Write to creds.txt" >> ~/Monitoring/qol/StoreCred.sh
    echo "echo \"'\$username':'\$password'\" >> ~/Loot/creds.txt" >> ~/Monitoring/qol/StoreCred.sh
    sudo chmod +x ~/Monitoring/qol/StoreCred.sh
    sudo ln -s ~/Monitoring/qol/StoreCred.sh /usr/local/bin/StoreCred
    echo "[+] StoreCred Deployed" >> ~/Report.txt
    # Hostname Script (adds hostnames to /etc/hosts)
    # Write the HOSTNAME script line-by-line
    echo "#!/bin/bash" > ~/Monitoring/qol/StoreHostname.sh
    echo "read -p \"Enter ip: \" ip" >> ~/Monitoring/qol/StoreHostname.sh
    echo "read -p \"Enter hostname(s) seperated by a space: \" hostname" >> ~/Monitoring/qol/StoreHostname.sh
    echo "echo" >> ~/Monitoring/qol/StoreHostname.sh
    echo "# Write to /etc/hosts" >> ~/Monitoring/qol/StoreHostname.sh
    echo "echo \"\$ip	\$hostname\" | sudo tee -a /etc/hosts > /dev/null" >> ~/Monitoring/qol/StoreHostname.sh
    sudo chmod +x ~/Monitoring/qol/StoreHostname.sh
    sudo ln -s ~/Monitoring/qol/StoreHostname.sh /usr/local/bin/StoreHostname
    echo "[+] StoreHostname Deployed" >> ~/Report.txt

    # Set default tab opening to the Loot directory
    echo 'cd ~/Loot' >> ~/.zshrc
    echo 'cd ~/Loot' >> ~/.bashrc
    echo "[+] Default Opening Directory Deployed" >> ~/Report.txt
fi

#===============================================================================
# Wrapping Up ==================================================================
#===============================================================================
# Finishing Print Statement
echo "[+] Lets Roll" >> ~/Report.txt
