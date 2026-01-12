roles hinzufügen:

- moonlight
  **terminal commands (incl drivers):**
  1760341918:0;sudo pacman -S moonlight
  : 1760342074:0;yay -S moonlight-qt
  : 1760342197:0;sudo pacman -S git base-devel
  : 1760342209:0;git clone https://aur.archlinux.org/moonlight-qt.git\
  cd moonlight-qt\

: 1760342215:0;makepkg -si
: 1760342795:0;cd ..
: 1760342857:0;sudo pacman -S vulkan-headers vulkan-icd-loader
: 1760342881:0;ls
: 1760342885:0;cd moonlight-qt
: 1760342889:0;makepkg -si
: 1760343162:0;sudo pacman -S vulkan-intel
: 1760343264:0;sudo pacman -S intel-media-driver
: 1760343545:0;cd .config/hypr
: 1760343550:0;nvim hyprland.conf
: 1760343679:0;moonlight

- nitch --> wget
  wget https://raw.githubusercontent.com/unxsh/nitch/main/setup.sh && sh setup.sh

  config File:
  src/funcs/drawing.nim

- sshfs
- nautilus
- iperf3
- hyprlock ?
- iamb
- swww
