# Dotfiles Refactoring Plan

## Pain Points (zusammengefasst)

### 1. Das User-Chaos
**Problem**: Man muss immer `target_user=lpalma` angeben. Noch schlimmer: `sudo nvim /etc/fstab` hat keine Config, weil root keinen Zugriff auf die User-dotfiles hat.

**Ursache**: `target_user` ist nicht sauber definiert und das ganze Privilege-Handling ist durcheinander.

### 2. Das become: yes Chaos
**Problem**: Alles läuft als root, dann wird mit `become_user` zurückgewechselt. Manche Roles haben `become: no` UND `become_user` gleichzeitig.

**Ursache**: AUR-Pakete (yay) können nicht als root kompiliert werden. Um das zu fixen, wurde alles verbogen.

### 3. Distro-Support unübersichtlich
**Problem**: Alle Distros in einer main.yml mit verschachtelten `when`-Conditions. Man sieht nicht sofort, was fehlt.

**Wunsch**: Pro Distro ein eigenes File (`archlinux.yml`, `debian.yml`, etc.)

### 4. Wrapper-Komplexität
**Problem**: Zwei Repos (dotfiles + homelab), dotfiles manuell auf Controller geklont, Playbook ruft Playbook auf. Funktioniert "semi-gut".

**Frage**: Wrapper weglassen oder sauber machen?

### 5. Hardcoded Pfade
**Problem**: Alles setzt `~/.dotfiles` voraus. Auf dem Controller liegt es woanders.

---

## Empfehlungen

### Empfehlung: Erst Dotfiles clean machen, DANN Wrapper vereinfachen

Der Wrapper ist nicht das Hauptproblem. Wenn die Dotfiles sauber strukturiert sind, wird der Wrapper trivial.

**Vorschlag für den Wrapper (später)**:
```yaml
# homelab/playbooks/setup-vm.yml
- name: Deploy dotfiles to VMs
  hosts: all
  vars:
    dotfiles_repo: "https://github.com/username/dotfiles.git"
    dotfiles_dest: "/home/{{ target_user }}/.dotfiles"
  tasks:
    - name: Clone dotfiles
      ansible.builtin.git:
        repo: "{{ dotfiles_repo }}"
        dest: "{{ dotfiles_dest }}"
        version: main
      become_user: "{{ target_user }}"

    - name: Run dotfiles playbook
      ansible.builtin.include_role:
        name: "{{ dotfiles_dest }}/roles/{{ item }}"
      loop: "{{ dotfiles_roles }}"
```

Aber erstmal: **Dotfiles fixen.**

---

## Lösung 1: User-Handling über Inventory

### Das Konzept

`target_user` wird in der Inventory pro Host definiert. Für localhost wird der aktuelle User automatisch verwendet.

```yaml
# inventory.yml
all:
  hosts:
    localhost:
      ansible_connection: local
      # Automatisch: aktueller User
      target_user: "{{ lookup('env', 'USER') }}"

  children:
    servers:
      vars:
        # Default für alle Server
        target_user: "lpalma"
      hosts:
        docker-swarm-01:
          ansible_host: 192.168.1.10
        docker-swarm-02:
          ansible_host: 192.168.1.11

    workstations:
      vars:
        target_user: "lpalma"
      hosts:
        arch-notebook:
          ansible_connection: local
```

### Das Root-Problem lösen

Wenn man `sudo nvim /etc/fstab` ausführt, sucht nvim nach `/root/.config/nvim`.

**Lösung A: Symlink von root zum User**
```yaml
# roles/nvim/tasks/main.yml (am Ende hinzufügen)
- name: Symlink nvim config for root user
  ansible.builtin.file:
    src: "/home/{{ target_user }}/.config/nvim"
    dest: "/root/.config/nvim"
    state: link
  become: yes
  tags: [nvim, client, server]
```

**Lösung B: SUDO_USER Environment Variable nutzen**

In der `.zshrc` oder als Shell-Alias:
```bash
alias sudo='sudo -E'  # Erhält Environment Variables
# ODER spezifisch für nvim:
alias svim='sudo -E nvim'
```

Empfehlung: **Lösung A** - einmal einrichten, immer funktioniert.

---

## Lösung 2: become: yes aufräumen

### Das Konzept

```
Regel 1: become: yes NUR für Tasks die root brauchen (package install, system files)
Regel 2: User-Configs IMMER mit become_user: "{{ target_user }}"
Regel 3: AUR-Pakete als separater Block mit eigenem become-Handling
```

### Vorher (chaotisch)
```yaml
# playbook.yml
- hosts: all
  become: yes  # <- Alles als root
  roles:
    - nvim

# roles/nvim/tasks/main.yml
- name: Install nvim
  package:
    name: neovim
  # läuft als root - OK

- name: Deploy config
  file:
    src: ...
    dest: "/home/{{ target_user }}/.config/nvim"
  become: no  # <- WTF, man ist doch schon root?
  become_user: "{{ target_user }}"  # <- macht so keinen Sinn
```

### Nachher (sauber)
```yaml
# playbook.yml
- hosts: all
  become: no  # <- Default: KEIN root
  vars:
    target_user: "{{ target_user | default(lookup('env', 'USER')) }}"
  roles:
    - nvim

# roles/nvim/tasks/main.yml
- name: Install neovim (needs root)
  ansible.builtin.package:
    name: neovim
    state: present
  become: yes  # <- Explizit root für package install

- name: Deploy nvim config
  ansible.builtin.file:
    src: "{{ dotfiles_path }}/roles/nvim/files"
    dest: "{{ ansible_env.HOME }}/.config/nvim"
    state: link
  # Kein become nötig - läuft als target_user
```

### AUR-Pakete richtig handhaben

```yaml
# roles/yay/tasks/archlinux.yml
- name: Install yay dependencies (needs root)
  ansible.builtin.package:
    name:
      - base-devel
      - git
  become: yes

- name: Clone yay repo
  ansible.builtin.git:
    repo: https://aur.archlinux.org/yay.git
    dest: "/tmp/yay-build"
  # Kein become - als User

- name: Build and install yay
  ansible.builtin.shell: |
    cd /tmp/yay-build && makepkg -si --noconfirm
  args:
    creates: /usr/bin/yay
  # Kein become - makepkg als User, sudo intern für install
```

---

## Lösung 3: Distro-spezifische Task Files

### Struktur

```
roles/
└── nvim/
    ├── tasks/
    │   ├── main.yml        # Router - entscheidet welches File
    │   ├── archlinux.yml   # Arch-spezifische Tasks
    │   ├── debian.yml      # Debian/Ubuntu Tasks
    │   ├── fedora.yml      # Fedora Tasks
    │   └── common.yml      # Gemeinsame Tasks (Config deployment)
    └── files/
        └── ...
```

### Router (main.yml)

```yaml
# roles/nvim/tasks/main.yml
---
- name: Include distro-specific tasks
  ansible.builtin.include_tasks: "{{ item }}"
  with_first_found:
    - files:
        - "{{ ansible_distribution | lower }}.yml"
        - "{{ ansible_os_family | lower }}.yml"
        - "unsupported.yml"
  tags: [nvim, always]

- name: Include common tasks
  ansible.builtin.include_tasks: common.yml
  tags: [nvim, always]
```

### Distro Files

```yaml
# roles/nvim/tasks/archlinux.yml
---
- name: Install neovim on Arch
  ansible.builtin.package:
    name: neovim
    state: present
  become: yes
  tags: [nvim]

# roles/nvim/tasks/debian.yml
---
- name: Install neovim on Debian/Ubuntu via snap
  community.general.snap:
    name: nvim
    classic: yes
  become: yes
  tags: [nvim]
  when: ansible_distribution == "Ubuntu"

- name: Install neovim on Debian via AppImage
  block:
    - name: Download nvim AppImage
      ansible.builtin.get_url:
        url: "https://github.com/neovim/neovim/releases/latest/download/nvim.appimage"
        dest: "/usr/local/bin/nvim"
        mode: '0755'
      become: yes
  when: ansible_distribution == "Debian"
  tags: [nvim]

# roles/nvim/tasks/fedora.yml
---
- name: Install neovim on Fedora
  ansible.builtin.dnf:
    name: neovim
    state: present
  become: yes
  tags: [nvim]

# roles/nvim/tasks/unsupported.yml
---
- name: Warn about unsupported distribution
  ansible.builtin.debug:
    msg: "WARNING: {{ ansible_distribution }} is not supported for nvim role"
  tags: [nvim]
```

### Common File (Config Deployment)

```yaml
# roles/nvim/tasks/common.yml
---
- name: Ensure config directory exists
  ansible.builtin.file:
    path: "{{ ansible_env.HOME }}/.config"
    state: directory
    mode: '0755'
  tags: [nvim]

- name: Deploy nvim config (symlink for clients)
  ansible.builtin.file:
    src: "{{ dotfiles_path }}/roles/nvim/files"
    dest: "{{ ansible_env.HOME }}/.config/nvim"
    state: link
  when: deployment_mode == 'symlink'
  tags: [nvim, client]

- name: Deploy nvim config (copy for servers)
  ansible.builtin.copy:
    src: files/
    dest: "{{ ansible_env.HOME }}/.config/nvim/"
    mode: preserve
  when: deployment_mode == 'copy'
  tags: [nvim, server]

- name: Symlink nvim config for root
  ansible.builtin.file:
    src: "{{ ansible_env.HOME }}/.config/nvim"
    dest: "/root/.config/nvim"
    state: link
  become: yes
  when: setup_root_config | default(true)
  tags: [nvim]
```

---

## Lösung 4: Zentrale Variablen

### group_vars/all/main.yml (NEU)

```yaml
# group_vars/all/main.yml
---
# Pfad zur dotfiles repo - anpassbar pro Umgebung
dotfiles_path: "{{ ansible_env.HOME }}/.dotfiles"

# Deployment Modus: 'symlink' für Clients, 'copy' für Server
deployment_mode: "copy"

# Root-User auch konfigurieren?
setup_root_config: true

# Standard-Pakete die überall installiert werden
base_packages:
  - git
  - curl
  - wget
  - unzip
```

### group_vars/clients.yml

```yaml
# group_vars/clients.yml
---
deployment_mode: "symlink"
```

### group_vars/servers.yml

```yaml
# group_vars/servers.yml
---
deployment_mode: "copy"
setup_root_config: true
```

---

## Lösung 5: Inventory Struktur

### Erweiterte Inventory

```yaml
# inventory.yml
---
all:
  vars:
    ansible_python_interpreter: auto

  children:
    # === LOCALHOST (Notebook) ===
    local:
      hosts:
        localhost:
          ansible_connection: local
          target_user: "{{ lookup('env', 'USER') }}"
          deployment_mode: symlink

    # === CLIENTS (Desktop/Workstations) ===
    clients:
      vars:
        deployment_mode: symlink
        target_user: lpalma
      hosts:
        # Weitere Arch Clients hier

    # === SERVER ===
    servers:
      vars:
        deployment_mode: copy
        target_user: lpalma
        setup_root_config: true

      children:
        # Docker Swarm Cluster
        docker_swarm:
          hosts:
            swarm-manager-01:
              ansible_host: 192.168.1.10
            swarm-worker-01:
              ansible_host: 192.168.1.11
            swarm-worker-02:
              ansible_host: 192.168.1.12

        # Proxmox Nodes
        proxmox:
          vars:
            # Proxmox hat eigene User-Struktur
            target_user: root
          hosts:
            pve-node-01:
              ansible_host: 192.168.1.5

        # Coding VMs (Fedora)
        coding:
          hosts:
            fedora-dev-01:
              ansible_host: 192.168.1.20
```

---

## Empfohlene Reihenfolge zum Refactoring

### Phase 1: Grundlagen

1. **group_vars/all/main.yml erstellen** mit `dotfiles_path`, `deployment_mode`, etc.
2. **playbook.yml umstellen** auf `become: no` als Default
3. **Eine Role komplett umbauen** (z.B. `nvim`) als Template:
   - `main.yml` als Router
   - `archlinux.yml`, `debian.yml`, `fedora.yml`
   - `common.yml` für Config-Deployment
   - Root-Symlink hinzufügen

### Phase 2: Roles migrieren

4. Alle Roles nach dem nvim-Template umbauen
5. `become: yes` nur noch explizit wo nötig
6. Typos fixen (isntall, insstall, etc.)

### Phase 3: Inventory & Wrapper

7. Inventory erweitern mit Host-Gruppen
8. Wrapper vereinfachen (oder ganz weglassen - einfach die Inventory im dotfiles-repo erweitern)

### Phase 4: Nice-to-have

9. Tags konsistent machen
10. README pro Role
11. CI/CD mit GitHub Actions (Syntax-Check, Lint)

---

## Quick Wins (sofort umsetzbar)

### 1. target_user Default setzen

```yaml
# playbook.yml - gleich am Anfang
vars:
  target_user: "{{ target_user | default(lookup('env', 'USER')) }}"
```

### 2. dotfiles_path Variable einführen

```yaml
# group_vars/all/main.yml
dotfiles_path: "{{ ansible_env.HOME }}/.dotfiles"
```

Dann in allen Roles `~/.dotfiles` durch `{{ dotfiles_path }}` ersetzen.

### 3. Root nvim Config

```bash
# Einmalig manuell ausführen:
sudo ln -sf /home/lpalma/.config/nvim /root/.config/nvim
sudo ln -sf /home/lpalma/.config/zsh /root/.config/zsh
```

Oder als Task in die entsprechenden Roles einbauen.
