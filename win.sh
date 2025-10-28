#!/bin/zsh
echo '
                        ++;++x++xx;;;    ::::: ;x+xXXXxXXXXXXx    
                     +XXXXXXXXXXXXXXX++;::::::;xx++;    +xxXXXX   
                  ;xXx++xXXXXXXXXXxxXXx+++;::::::       ++   +X+  
               ;XXXX++XXXXXxXXXXXXXXXXX+;;;;;::;;;;;          ;   
              ;xxXXX+xXXXXXXXXXXXXXXXXXXx;;;;;;;::;;;             
             ;xxXxXXXXXXXXXXXXXXXXXXXXXXXx;;;;;::...;;            
         ++++xXxxXxxxx+xXXXXXXXxXXXXX$XXXXx;;;;;;;;;              
          +xXXxXXxxxxx+;XXXXX$$XXXXXXXXXXXx+;;;;;;                
           ++xXXXXxxxx+XXXXXXXXxxXxXXXXXXXXx;;;;;;                
          +xxXXXXXXXx+XXXXXXXXXx+xXxXXXXXXxx+;;;;;                
         +xxXXXXXXXXx++XXXXXXXX+x+xXxXXXXXxXx;:;;;;;;;;;;;;;    
     xx++xxXXXXXxxXX+x$xXXXXxXX+X$x+xxxXXXXxXx;;;;;;;;;;;;;;;;   
   xxXXxxXXXXXXXxXX+xXX$XxXXxxxX$$$Xx+++XXXxxXx;;;;;;;;;;;;;;;;  
 xxXXxXXXXXXXXXxxXxx$$$XX$xxXxxXXX$$$$x++xXxxXX+;;;;;;;;;;;   ;; 
xXXx +XXXxXXXXxx+;++XXx+xX$XxxxxxXXx+;:+XX+xXXXx;;;;;;;;;;;;;  ;;
XX  +xxXXx+XXXX+X$xx;..;$$$XX$$$X+x..;+$$$XxXXX;;;;;;;;;;;;;;;  ;;
XxxxXx+xX+;;+xXxX$$X;+X$$$$X$$$$$X;;xX$XXXxXXx;;;;;;;;;;;;;;;;;;+;
xxXXXXxXx+;;;;;xxxxXXXX$$$$$$$$$$$$XXXXxxXxx++;;;;;;;;;;;;;+++;+;
 xXXXXXXX+;;;;;;;XXXXXX$$$$X$$$$$$$$X$$$$X+++;;;;;;;;;;;;+;++;;:
  xXXXXXXx;;;;;;;x$$$$$$$$$$$$$$$XXXx$$$$+;;;;;;++;+++++++++;  ;
    xX+xXX+;;   +x$$$$$$Xx$$$$$$$$X+$$$$+++++++; ;;++++++;++++;;
   xXXx+XXx;;   ;+x$$$$$$$XX$$$XXX$$XX+++++++   ;;++++++    ;;
        +xXXx+;     xxxXX$$$$$$$$XX$$x+++  ;   +++;+;++++
                ;+++  x$$X+xXXxX$$X+; ;      +++;
              ++++++  x$XXxX$$Xx+++++     ;++++;;
          xXXX++xx+;xXXX$$$$$$$$Xx++++;;;+++++++++++;
         X$$$$x++++x$$$$$$$$$$$X$x+xXxx+++++++;+++++++
        x$$$$$Xx+++X$$$$$$$$$$XXXX$XXx+++;;+;++++++++;
       +XXXXXXX+++XX$$$$$$$$$$$XXXxXx+++++++++XXX++++;
       +XXXXX++++xXXXXXXXXXXxxXXXXx+++++++++:xXXX++++;
       +XXXXX++++++++++;::::;+x++++++++++:::;XXX+++++;'

# the big install
sudo DEBIAN_FRONTEND=noninteractive apt update -y -qq > /dev/null 2>&1
sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq masscan curl terminator git python3-dev faketime apt-transport-https ca-certificates gnupg lsb-release build-essential pkg-config libssl-dev libkrb5-dev libclang-dev clang libgssapi-krb5-2 krb5-user cifs-utils yq golang-go > /dev/null 2>&1

# docker
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo DEBIAN_FRONTEND=noninteractive apt update -y -qq > /dev/null 2>&1
sudo DEBIAN_FRONTEND=noninteractive apt install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
sudo curl -sSL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo systemctl start docker
sudo systemctl enable docker > /dev/null 2>&1
sudo usermod -aG docker $USER

# rustup
curl https://sh.rustup.rs -sSf | sh -s -- -y > /dev/null 2>&1
source "$HOME/.cargo/env"

# uv and tools
curl -LsSf https://astral.sh/uv/install.sh | sh > /dev/null 2>&1
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
uv tool install git+https://github.com/Pennyw0rth/NetExec.git -q
uv tool install git+https://github.com/ly4k/Certipy.git -q
uv tool install git+https://github.com/fortra/impacket.git -q
uv tool install git+https://github.com/CravateRouge/bloodyAD.git -q
uv tool install git+https://github.com/dirkjanm/BloodHound.py.git@bloodhound-ce -q
uv tool install git+https://github.com/adityatelange/evil-winrm-py -q

# shell
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended" >/dev/null 2>&1
git clone -q https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone -q https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone -q https://github.com/zdharma-continuum/fast-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting
sed -i 's/^plugins=(git)$/plugins=(git zsh-syntax-highlighting zsh-autosuggestions fast-syntax-highlighting)/' ~/.zshrc
sed -i 's/robbyrussell/minimal/g' ~/.zshrc

# rusthound
cargo install --quiet rusthound-ce
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc

# rockyou
curl -sSLo ~/rockyou.txt https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt

# bloodhound setup
mkdir -p ~/bloodhound
curl -sSLo ~/bloodhound/docker-compose.yml https://ghst.ly/getbhce
sg docker -c 'docker-compose -f ~/bloodhound/docker-compose.yml pull -q'
sg docker -c '
BLOODHOUND_HOST=0.0.0.0 BLOODHOUND_PORT=8888 docker-compose -f ~/bloodhound/docker-compose.yml up -d

echo "Girls are now preparing BloodHound, please wait warmly... ☯"
until curl -s -f http://localhost:8888 >/dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo " Ready!"

'
sg docker -c 'echo $(docker logs $(docker ps -qf "ancestor=specterops/bloodhound:latest") | grep -i "initial password") | cut -d# -f2'
source ~/.zshrc
