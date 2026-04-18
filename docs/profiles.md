# Profiles — pro Host/Nutzer unterschiedliche Configs

## Worum es geht

Manche Rollen sollen auf verschiedenen Hosts bzw. für verschiedene Nutzer **unterschiedlich** aussehen — z.B. Hyprland mit anderem Colorscheme für mich und meine Freundin. Gleichzeitig soll weiterhin sauber steuerbar sein, **ob** eine Rolle überhaupt auf einem Host läuft (z.B. Hyprland nur auf Hosts mit `wayland`-Capability).

Dafür zwei getrennte Mechanismen:

- **Capabilities** entscheiden, *ob* eine Rolle läuft.
- **Profile / Vars** entscheiden, *wie* sie konfiguriert wird.

Die Trennung ist wichtig: eine Capability auszuknipsen soll nicht das Profil mitreißen, und ein Profilwechsel soll nicht das Feature-Set eines Hosts verändern.

## Capabilities (Gating)

In `host_vars/<host>.yml`:

```yaml
# host_vars/arch_book.yml
capabilities: [gui, wayland, systemd]
```

Im Playbook wird pro Rolle konditional eingebunden:

```yaml
- hosts: dotfiles
  roles:
    - { role: lpalma.dotfiles.btop,     tags: [btop],     when: "'cli' in capabilities | default([])" }
    - { role: lpalma.dotfiles.hyprland, tags: [hyprland], when: "'wayland' in capabilities | default([])" }
```

Tipp: `capabilities: []` in `group_vars/dotfiles.yml` als Default setzen — dann erübrigt sich das `| default([])` an jedem Use-Site.

## Profile (Varianten)

In `host_vars/<host>.yml` zusätzlich ein Profil-Bezeichner:

```yaml
# host_vars/arch_book.yml
capabilities: [gui, wayland, systemd]
dotfiles_profile: linus
```

```yaml
# host_vars/paula_laptop.yml
capabilities: [gui, wayland, systemd]
dotfiles_profile: paula
```

Ab hier zwei Muster — je nach Komplexität der Unterschiede.

### Muster A — ein Template, Vars pro Profil (bevorzugt)

Passt, wenn sich Profile nur in **wenigen Werten** unterscheiden (Farben, Font, Wallpaper). Skaliert am besten, weil der gemeinsame Teil der Config nicht dupliziert wird.

Struktur:

```
roles/hyprland/
├── tasks/
│   └── install.yml
├── templates/
│   └── hyprland.conf.j2
└── vars/
    └── profiles/
        ├── default.yml
        ├── linus.yml
        └── paula.yml
```

`vars/profiles/linus.yml`:

```yaml
hyprland_colorscheme: catppuccin-mocha
hyprland_font: "JetBrainsMono Nerd Font"
hyprland_wallpaper: ~/Pictures/wallpapers/mountain.jpg
```

`tasks/install.yml`:

```yaml
- name: load profile vars
  ansible.builtin.include_vars: "{{ item }}"
  with_first_found:
    - files: ["{{ dotfiles_profile | default('default') }}.yml"]
      paths: ["vars/profiles"]
      skip: true

- name: deploy hyprland config
  ansible.builtin.template:
    src: hyprland.conf.j2
    dest: "~/.config/hypr/hyprland.conf"
```

Im Template werden die Vars ganz normal referenziert (`{{ hyprland_colorscheme }}` etc.).

### Muster B — Template pro Profil

Passt, wenn sich Profile **strukturell** unterscheiden (andere Keybind-Philosophie, anderer Workspace-Aufbau). Separates Template pro Profil ist dann ehrlicher als ein Mega-Jinja mit 20 `if`-Blöcken.

Struktur:

```
roles/hyprland/templates/
├── default/hyprland.conf.j2
├── linus/hyprland.conf.j2
└── paula/hyprland.conf.j2
```

`tasks/install.yml`:

```yaml
- name: deploy hyprland config
  ansible.builtin.template:
    src: "{{ dotfiles_profile | default('default') }}/hyprland.conf.j2"
    dest: "~/.config/hypr/hyprland.conf"
```

Hier braucht es **keine** `vars/profiles/<name>.yml` — der Profilname aus `host_vars` reicht als Pfadsegment.

## Faustregel

| Unterschied zwischen Profilen | Muster |
|-------------------------------|--------|
| wenige Werte (Farbe, Font, Wallpaper) | A — ein Template, Vars pro Profil |
| strukturell andere Config | B — Template pro Profil |

Im Zweifel mit **A** anfangen. Nach **B** migrieren, sobald das gemeinsame Template zu viele Fallunterscheidungen enthält.
