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
├── galaxy.yml                     # Collection-Metadaten + build_ignore
├── README.md
├── requirements.yml               # falls eigene Collection-Deps
├── roles/
│   ├── nvim/
│   ├── hyprland/
│   ├── waybar/
│   ├── zsh/
│   ├── docker/
│   └── ...                        # eine Rolle pro Programm
├── playbooks/                     # collection-interne playbooks, aus homelab nutzbar
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

## Collection-Build: `build_ignore`

Wenn die Collection via `type: git` installiert wird, ruft `ansible-galaxy` intern `collection build` auf und installiert das resultierende Tarball. `build_ignore` in `galaxy.yml` filtert, was ins Tarball landet — also was im Consumer-Repo (homelab) tatsächlich ankommt. Ohne Filter landet alles (incl. `.git`, lose Test-Playbooks, interne Docs) beim Consumer.

```yaml
# galaxy.yml
namespace: lpalma
name: dotfiles
version: 0.1.0
readme: README.md
authors: [lpalma]
description: setup / dotfiles via ansible for clients and server
license: [MIT]
repository: https://github.com/linuspalma/dotfiles

build_ignore:
  - .git
  - .github
  - .gitignore
  - .claude
  - .vscode
  - docs
  - pb                     # lokale test-playbooks falls existent
  - inventories            # standalone-only
  - ansible.cfg
  - '*.pyc'
  - '__pycache__'
```

Patterns sind `fnmatch`-style, relativ zur Collection-Root. `galaxy.yml`, `README.md` und `roles/` werden immer inkludiert.

**Verifikation:**

```bash
ansible-galaxy collection build --force
tar tzf lpalma-dotfiles-*.tar.gz
```

Zeigt exakt den Tarball-Inhalt — falls `pb/` oder `docs/` noch auftauchen, stimmt das Pattern nicht.

## Konvention pro Rolle

Jede Rolle kapselt **install + deps + config** atomar ("Dotfiles+"). Kein reines File-Copy wie bei stow/chezmoi — eine Rolle liefert ein funktionsfähiges Programm.

### Struktur

```
roles/<programm>/
├── defaults/main.yml          # user-überschreibbare defaults (auto-loaded)
├── vars/                      # nur wenn OS-Unterschiede existieren
│   ├── Archlinux.yml          # matcht ansible_os_family
│   └── Debian.yml
└── tasks/
    ├── main.yml               # os-vars laden + op dispatchen
    ├── install.yml            # default op
    ├── remove.yml             # optional, erst bauen wenn gebraucht
    └── update.yml             # optional
```

`defaults/main.yml` hält, was der Caller tweaken dürfen soll (z.B. Paketname mit vernünftigem Default, Feature-Flags). `vars/<ansible_os_family>.yml` überschreibt pro OS, falls nötig. Triviale Rollen (btop, unzip) brauchen `vars/` gar nicht — der Default aus `defaults/main.yml` reicht.

**Kein `meta/main.yml`-Custom-Schema.** Ansible lädt `meta/main.yml` nur für `galaxy_info`, `dependencies`, `collections`, `argument_specs`. Custom-Keys dort (supported_os, category, …) bringen ohne Discovery-Tool keinen echten Mehrwert, sind aber eine weitere Quelle, die mit dem Code synchron gehalten werden muss. Weglassen. Die tatsächliche Support-Matrix ist `ls roles/<name>/vars/`.

### Op-Dispatcher

Einheitliches Pattern über alle Domänen des homelabs: eine Extra-Var **`op`** selektiert die Task-Gruppe. (Vormals `dotfile_action` — auf `op` vereinheitlicht. `action` kollidiert mit einem Ansible-Built-in und fällt deshalb aus.)

`op` ist keine Eigenbau-Mechanik — `include_tasks` mit variabler Dateiname ist Ansibles nativer Dispatch-Weg. Der Unterschied zu `import_role: tasks_from:` liegt im **Zeitpunkt der Entscheidung**:

| Mechanismus | Wann wird entschieden | Wer entscheidet |
|---|---|---|
| `tasks_from:` | Playbook-Schreibzeit | Playbook-Autor |
| `include_tasks: "{{ op }}.yml"` | `ansible-playbook`-Aufruf | Benutzer an der Kommandozeile |

Der Runtime-Dispatch via `op` erlaubt **ein** Homelab-Playbook (`pb/dotfiles.yml`) für install/remove/update statt dreier paralleler Files.

```yaml
# tasks/main.yml — minimal
---
- name: load os-specific vars (if any)
  ansible.builtin.include_vars: "{{ item }}"
  with_first_found:
    - files: ["{{ ansible_os_family }}.yml"]
      paths: ["vars"]
      skip: true

- ansible.builtin.include_tasks: "{{ op | default('install') }}.yml"
```

**Keine Asserts im Dispatcher.** `include_tasks` mit falschem `op` failed von selbst (`Could not find or access '.../frobnicate.yml'`); `include_vars` mit `skip: true` ist lautlos, wenn die OS-Datei fehlt (Default aus `defaults/main.yml` gilt weiter). Wenn ein Paket auf einem unbekannten OS fehlt, schlägt der eigentliche `package:`-Task mit ausreichend klarer Message fehl. Jeder zusätzliche Assert ist Belt+Suspenders mit eigener Drift-Falle (zweite Source-of-Truth neben dem Dateisystem).

**Invocation:**

```bash
ansible-playbook pb/dotfiles.yml --tags nvim                       # install (default op)
ansible-playbook pb/dotfiles.yml --tags nvim -e op=remove          # remove
ansible-playbook pb/dotfiles.yml --tags nvim -e op=update          # update
```

**Tag-Semantik**: Tags = Nomen (welche Rolle), Extra-Var `op` = Verb (welche Action). Identisch mit Swarm — ein einziges Mental-Model.

**YAGNI für `remove`**: erst bauen wenn konkret nötig. Dotfile-Remove ist haariger als Swarm-Remove (Pakete, Configs, systemd-Units, System-Tweaks).

### OS-Unterschiede via per-OS-Vars-Files

Für jeden OS, der vom Default abweicht, eine Datei `vars/<ansible_os_family>.yml`. Der Dispatcher lädt sie via `first_found` + `skip: true` — fehlt die Datei, bleibt der Default aus `defaults/main.yml` gültig.

```yaml
# defaults/main.yml
---
nvim_package: neovim          # 80%-Default
nvim_config_path: ~/.config/nvim
```

```yaml
# vars/Archlinux.yml          # nur falls Arch abweicht oder Zusatzdaten hat
---
nvim_extras: [tree-sitter-cli, ripgrep]
nvim_install_method: yay
```

```yaml
# vars/Debian.yml
---
nvim_ppa: neovim-ppa/stable
nvim_install_method: apt
```

```yaml
# tasks/install.yml (bei trivialen Unterschieden, gleicher Paketname)
---
- ansible.builtin.package:
    name: "{{ nvim_package }}"
    state: present
  become: true
```

**Vorteile gegenüber einem zentralen `os_matrix`-Dict in `vars/main.yml`:**

- **Asymmetrie erlaubt.** `nvim_ppa` existiert nur für Debian, `aur_helper` nur für Arch. Im Dict müsstest du Null-Einträge schleppen oder mit `default()`-Magie arbeiten.
- **Diff-lokal.** Eine OS-Änderung berührt genau eine Datei.
- **Progressive Enhancement.** Triviale Rollen brauchen nur `defaults/`. Sobald ein OS abweicht, kommt `vars/<OS>.yml` dazu, ohne den Rest umzubauen.
- **`ls roles/<programm>/vars/`** ist die Support-Matrix auf einen Blick.

**Escape-Hatch — strukturell unterschiedlicher Install** (AUR auf Arch, COPR auf Fedora, PPA auf Ubuntu):

```
roles/<programm>/tasks/
├── main.yml
├── install.yml             # OS-dispatcher
├── install/
│   ├── Archlinux.yml
│   ├── Debian.yml
│   └── _unsupported.yml    # fail mit Message
├── remove.yml
└── remove/
    └── Archlinux.yml
```

`install.yml`:
```yaml
- ansible.builtin.include_tasks: "install/{{ ansible_os_family }}.yml"
```

**Vorteil des Dispatchers**: `tree roles/<programm>/tasks/` zeigt auf einen Blick, welche OS-Kombinationen implementiert sind und welche fehlen.

### Configs sind OS-agnostisch

Die eigentlichen Dotfiles-Inhalte (`init.lua`, `hyprland.conf`, …) sind in aller Regel distro-unabhängig — ein Jinja2-Template. Was pro OS variieren kann ist der **Zielpfad** (XDG vs. Legacy, unterschiedliche Config-Dirs); der landet in `vars/<OS>.yml` als z.B. `nvim_config_path`, das Template bleibt trotzdem eines.

Trennung:

- **OS-sensitiv**: Paketname, Service-Name, Config-Pfad → `vars/<OS>.yml` bzw. `defaults/`
- **OS-agnostisch**: Template-Inhalt (Jinja2)

## Host-Komposition: drei getrennte Dimensionen

Die alte Idee "Tags `server`/`client` auf Tasks" hat drei orthogonale Fragen in einen Mechanismus gepresst. Sauber aufgeteilt:

| Dimension | Frage | Mechanismus |
|---|---|---|
| **Host-Auswahl** | Welche Hosts werden überhaupt angefasst? | Inventory-Gruppen (`hosts: dotfiles`) |
| **Rollen-Gating** | Welche Rollen passen zu diesem Host? | Capability-Matching (`when: "'gui' in capabilities"` am Role-Include) |
| **Task-Filter** | Welche Subset läuft in diesem Run? | `--tags <rolle>` + `-e op=<verb>` |

### Host-Auswahl: Inventory-Gruppen

Wer dotfiles bekommt, entscheidet das Inventory — nicht das Playbook und nicht eine Capability. Hosts, die gar keine Dotfiles wollen (HomeAssistant-Appliance, Swarm-Nodes), landen einfach nicht in der Gruppe.

```yaml
# homelab/inventory.yml
all:
  children:
    dotfiles:
      hosts:
        archbook: {}
        homeserver: {}
        arch-vm: {}
    appliances:
      hosts:
        homeassistant: {}
```

```yaml
# homelab/pb/dotfiles.yml
- hosts: dotfiles                      # ← host-selection
  roles:
    - { role: lpalma.dotfiles.btop,      tags: [btop] }
    - { role: lpalma.dotfiles.fastfetch, tags: [fastfetch] }
    - { role: lpalma.dotfiles.nvim,      tags: [nvim] }
    - { role: lpalma.dotfiles.hyprland,  tags: [hyprland],
        when: "'gui' in capabilities" }
    - { role: lpalma.dotfiles.waybar,    tags: [waybar],
        when: "'gui' in capabilities" }
```

**Szenario "fastfetch-Änderung auf alle Dotfiles-Hosts ausrollen":**

```bash
ansible-playbook pb/dotfiles.yml --tags fastfetch -e op=update
```

Homeassistant wird nicht kontaktiert (nicht in der Gruppe), archbook und homeserver bekommen das Update, andere Rollen laufen nicht (Tag-Filter).

### Rollen-Gating: Capabilities am Role-Include

Nicht jede Rolle passt auf jeden Dotfiles-Host: Hyprland auf dem headless Homeserver wäre Unsinn. Dafür deklariert der Host in `host_vars/<hostname>.yml` seine Capabilities, und der Role-Include im Playbook gatet via `when:`.

- Host deklariert: `capabilities: [gui, wayland, systemd]` — was er anbietet
- Playbook gatet: `- { role: hyprland, when: "'gui' in capabilities" }` — was die Rolle braucht

**Am Playbook-Level, nicht im Role-Dispatcher.** Vorteile:

- Am Einsatzort sichtbar (Playbook lesen = wissen, wer was kriegt)
- Die Rolle selbst bleibt pur (kein Custom-Schema, keine Asserts)
- Für Standalone-Use: wenn im Standalone-Playbook kein `when:` steht, läuft die Rolle — kein Duplizieren der Logik in jeder Rolle

**Capabilities pro Host, nicht per Group:**

Heterogene Server (systemd vs. openrc, Desktop-Server mit GUI vs. headless) würden durch ein `group_vars/servers.yml: capabilities: [systemd]` belogen. Daher **in `host_vars/<hostname>.yml` explizit** die vollständige Liste:

```yaml
# host_vars/archbook.yml
capabilities: [gui, wayland, systemd, network_manager]

# host_vars/homeserver.yml
capabilities: [systemd]

# host_vars/alpine-edge.yml             # kein systemd
capabilities: [openrc]
```

Group_vars darf's weiter geben, aber für andere Zwecke (SSH-User, Inventory-Organisation) — nicht als zentrale Capability-Quelle. Wer doch vererben will: zwei Vars (`base_capabilities` auf Group-, `extra_capabilities` auf Host-Ebene) in `pre_tasks` zu `capabilities` zusammensetzen. Pragmatisch ist Explicit-per-Host ehrlicher bei heterogenen Flotten.

**Rollen splitten, wenn headless/GUI unabhängig sind:**

Für Software mit sauber getrennten headless- und GUI-Anteilen lieber zwei fokussierte Rollen als eine mit `when:`-Gates innerhalb — matcht die DE-Bundling-Logik weiter unten:

- `nextcloud_sync` — headless CLI/Daemon, kein Gate nötig
- `nextcloud_gui` — Desktop-Client, `when: "'gui' in capabilities"`

Server-Playbook includet nur `nextcloud_sync`, Workstation beide.

### Task-Filter: Tags + Op

Tags = Nomen (welche Rolle), `op` = Verb (welche Action). Orthogonal zur Host- und Rollen-Ebene. `--tags config` als Zusatz-Dimension für "nur Config-Re-Render, kein Install" bleibt ein legitimer Use.

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

| Thema                     | Entscheidung                                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------------ |
| Repo-Trennung             | Dotfiles public, homelab private, getrennt bleiben                                               |
| Distribution              | Ansible Collection, via Git-URL in `requirements.yml`                                            |
| Collection-Build          | `build_ignore` in `galaxy.yml` filtert Consumer-Payload                                          |
| Rolle pro Programm        | install + deps + config atomar                                                                   |
| Op-Dispatcher             | Extra-Var `op`, nativ via `include_tasks: "{{ op \| default('install') }}.yml"`                  |
| Asserts im Dispatcher     | **keine** — `include_tasks`/`include_vars` failen selbst mit brauchbarer Message                 |
| `meta/main.yml`           | nur ansible-eigene Keys (`galaxy_info`, `dependencies`); **kein** Custom-Schema                  |
| OS-Handling (Standard)    | `defaults/main.yml` + `vars/<ansible_os_family>.yml` via `first_found` + `skip: true`            |
| OS-Handling (Strukturell) | verschachtelter Dispatcher `tasks/install/<os>.yml`                                              |
| Configs                   | Template-Inhalt OS-agnostisch; Zielpfad über per-OS-Var                                          |
| Host-Auswahl              | Inventory-Gruppe `[dotfiles]`, nicht Capability                                                  |
| Rollen-Gating             | `when: "'<cap>' in capabilities"` am Role-Include im Playbook, nicht im Role-Dispatcher          |
| Capabilities-Quelle       | `host_vars/<hostname>.yml`, explizit pro Host                                                    |
| Theming                   | Palette-Var in `vars/themes/<name>.yml`, `active_theme` pro Host                                 |
| DE-Bundling               | Composition im Playbook, keine Meta-Rollen by default                                            |
| Playbooks in Collection   | Ja — dual-use standalone + library; `pb/` (standalone-only) via `build_ignore` ausgeklammert     |
