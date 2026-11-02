sudo apt update
sudo apt install -y flameshot tmux seclists docker.io docker-compose
mkdir -p ~/.config/flameshot
printf "[General]\nuseX11LegacyScreenshot=true\n" >> ~/.config/flameshot/flameshot.ini
sudo systemctl enable --now docker
sudo usermod -aG docker kali
