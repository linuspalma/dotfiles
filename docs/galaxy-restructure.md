# Dotfiles — Struktur & Anforderungen

## Ziel

Dotfiles werden als eigenständige **Ansible Collection** in einem **public Repo** gehalten. Zwei Konsumwege:

1. **Standalone / Portfolio**: Repo klonen, lokales Playbook ausführen → fertig bootstrappte Workstation. Zeigt nicht nur die Zutaten, sondern auch das komplette Setup.
2. **Als Library aus dem homelab**: Homelab zieht die Collection via `requirements.yml` und nutzt einzelne Rollen in seinen Target-Playbooks (`archbook.yml`, `server-foo.yml`, …).

Bewusst **nicht** ins homelab-Monorepo integriert, weil:

- Portfolio-Wert
- Leak-Risiko bei gemischten public/private Commits vermeidbar

## Top-Level-Struktur (dotfiles-Repo)

```
dotfiles/
├── galaxy.yml                     # Collection-Metadaten
├── README.md
├── requirements.yml               # falls eigene Collection-Deps
├── roles/
│   ├── nvim/
│   ├── hyprland/
│   ├── waybar/
│   ├── zsh/
│   ├── docker/
│   └── ...                        # eine Rolle pro Programm
├── playbooks/
│   ├── desktop.yml                # full desktop bootstrap
│   ├── server.yml                 # minimal server setup
│   └── dev-only.yml               # nur dev-tools
└── inventories/
    └── localhost.yml              # für standalone self-bootstrap
```

## Einbindung aus homelab

`homelab/requirements.yml`:

```yaml
collections:
  - name: lpalma.dotfiles
    source: https://github.com/lpalma/dotfiles.git
    type: git
    version: main # oder tag / commit
```

Install-Flow: `ansible-galaxy collection install -r requirements.yml --force`

Kein Galaxy-Server nötig — `type: git` reicht. Später optional gegen eigene Forgejo-Instanz austauschbar.

Nutzung in Target-Playbooks:

```yaml
# archbook.yml
roles:
  - _shared/updates
  - lpalma.dotfiles.hyprland
  - lpalma.dotfiles.nvim
  - lpalma.dotfiles.kitty
```

## Konvention pro Rolle

Jede Rolle kapselt **install + deps + config** atomar ("Dotfiles+"). Kein reines File-Copy wie bei stow/chezmoi — eine Rolle liefert ein funktionsfähiges Programm.

### Action-Dispatcher

Einheitliches Pattern über alle Domänen des homelabs: eine Extra-Var **`op`** selektiert die Task-Gruppe. (Vormals `dotfile_action` — auf `op` vereinheitlicht, siehe `global-structure.md`. `action` kollidiert mit einem Ansible-Built-in und fällt deshalb aus.)

```
roles/<programm>/
├── meta/main.yml          # deklariert supported_ops + default_op
└── tasks/
    ├── main.yml           # dispatcher
    ├── install.yml        # default
    ├── remove.yml         # optional, erst bauen wenn gebraucht
    └── update.yml         # optional
```

`main.yml`:

```yaml
- include_tasks: "{{ op | default('install') }}.yml"
```

`meta/main.yml`:

```yaml
galaxy_info: ...
supported_ops: [install, remove, update]
default_op: install
```

**Invocation:**

```bash
ansible-playbook pb/archbook.yml --tags nvim                       # install (default op)
ansible-playbook pb/archbook.yml --tags nvim -e op=remove          # remove
ansible-playbook pb/archbook.yml --tags nvim -e op=update          # update
```

**Tag-Semantik**: Tags = Nomen (welche Rolle), Extra-Var `op` = Verb (welche Action). Identisch mit Swarm — ein einziges Mental-Model.

**YAGNI für `remove`**: erst bauen wenn konkret nötig. Dotfile-Remove ist haariger als Swarm-Remove (Pakete, Configs, systemd-Units, System-Tweaks).

### OS-Dimension

Zwei Muster je nach Komplexität:

**Default — nur Paketnamen unterscheiden sich** (80% der Rollen):

```
roles/nvim/
├── vars/
│   ├── archlinux.yml       # nvim_package: neovim
│   ├── fedora.yml          # nvim_package: neovim
│   └── debian.yml          # nvim_package: neovim
└── tasks/
    ├── main.yml
    ├── install.yml         # nutzt ansible.builtin.package + nvim_package
    ├── configure.yml       # OS-agnostisch, Templates nach ~/.config
    └── remove.yml
```

`install.yml` lädt `vars/{{ ansible_distribution | lower }}.yml` und nutzt `ansible.builtin.package`.

**Escape-Hatch — strukturell unterschiedlicher Install** (AUR auf Arch, COPR auf Fedora, PPA auf Ubuntu):

```
roles/<programm>/tasks/
├── main.yml
├── install.yml             # OS-dispatcher
├── install/
│   ├── archlinux.yml
│   ├── fedora.yml
│   └── _unsupported.yml    # fail mit Message
├── remove.yml
└── remove/
    └── archlinux.yml
```

`install.yml`: `include_tasks: "install/{{ ansible_distribution | lower }}.yml"`

**Vorteil des Dispatchers**: `tree roles/<programm>/tasks/` zeigt auf einen Blick, welche OS-Kombinationen implementiert sind und welche fehlen.

### Configs sind OS-agnostisch

Die eigentlichen Dotfiles (`.config/nvim/init.lua`, `hyprland.conf`, …) sind in aller Regel distro-unabhängig. Trennung einhalten:

- **OS-sensitiv**: Package-Install
- **OS-agnostisch**: Config-Templates

## Zwei Dimensionen: Client/Server/Both

Bestehendes Tag-Pattern in der Collection behalten — jede Rolle ist via Tag als `client`, `server` oder `both` klassifiziert. Erlaubt `--tags client` zum Filtern. Kein Role-Split nötig.

## Theming via Variablen-Palette

Zentrale Palette, alle Templates referenzieren sie:

```yaml
# vars/themes/dark.yml
theme:
  name: dark
  bg:     "#1a1b26"
  fg:     "#c0caf5"
  accent: "#7aa2f7"

# vars/themes/pinkie.yml
theme:
  name: pinkie
  bg:     "#1a0f1a"
  fg:     "#f5d0e0"
  accent: "#ff6ac1"
```

Zuweisung via `host_vars/<hostname>.yml`:

```yaml
active_theme: dark # oder pinkie
```

Jede Rolle lädt: `include_vars: "themes/{{ active_theme }}.yml"`

Templates referenzieren `{{ theme.bg }}`, `{{ theme.accent }}` etc. Ein Theme-Wechsel = eine Variable umstellen, Playbook laufen lassen.

## DE-Bundling (Hyprland vs Niri vs Gnome)

**Composition auf Playbook-Ebene**, nicht als Meta-Rolle. Inkompatibilität löst sich dadurch automatisch — Waybar im Gnome-Playbook einfach nicht includen. Keine `when`-Spaghetti.

```yaml
# archbook-hyprland.yml
roles:
  - lpalma.dotfiles.hyprland
  - lpalma.dotfiles.waybar
  - lpalma.dotfiles.wofi
  - lpalma.dotfiles.nvim

# archbook-gnome.yml
roles:
  - lpalma.dotfiles.gnome
  - lpalma.dotfiles.gnome-extensions
  - lpalma.dotfiles.nvim
```

Ausnahme: wenn ein Bundle 3+ Mal identisch wiederverwendet wird, Meta-Rolle `lpalma.dotfiles.desktop_hyprland` rechtfertigt sich. Vorher nicht.

Optionaler Fail-Safe gegen Bedienfehler:

```yaml
pre_tasks:
  - assert:
      that: desktop_env == "hyprland"
      fail_msg: "Dieses Playbook ist nur für Hyprland-Setups"
```

## Entscheidungen — Zusammenfassung

| Thema                     | Entscheidung                                                     |
| ------------------------- | ---------------------------------------------------------------- |
| Repo-Trennung             | Dotfiles public, homelab private, getrennt bleiben               |
| Distribution              | Ansible Collection, via Git-URL in `requirements.yml`            |
| Rolle pro Programm        | install + deps + config atomar                                   |
| Action-Dispatcher         | Einheitliche Extra-Var `op` über alle Domänen                    |
| OS-Handling (Standard)    | `vars/<os>.yml` + `ansible.builtin.package`                      |
| OS-Handling (Strukturell) | verschachtelter Dispatcher `tasks/install/<os>.yml`              |
| Configs                   | OS-agnostisch in `configure.yml`                                 |
| Theming                   | Palette-Var in `vars/themes/<name>.yml`, `active_theme` pro Host |
| DE-Bundling               | Composition im Playbook, keine Meta-Rollen by default            |
| Playbooks in Collection   | Ja — dual-use standalone + library                               |
