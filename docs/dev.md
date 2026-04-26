# Development Workflow

## Local role development via symlink

Um die ständige commit → push → `collection install --force` Schleife während der
Entwicklung einer Rolle zu vermeiden, kann die Rolle aus diesem Repo direkt in die
installierte Collection im homelab-Repo gesymlinkt werden.

### Setup (Beispiel: btop)

```bash
rm -rf /home/lpalma/homelab/collections/ansible_collections/lpalma/dotfiles/roles/btop
ln -s /home/lpalma/dotfiles/roles/btop /home/lpalma/homelab/collections/ansible_collections/lpalma/dotfiles/roles/btop
```

Syntax: `ln -s <ziel> <linkname>` — erst das echte Verzeichnis (Quelle in dotfiles),
dann wo der Symlink liegen soll (in der installierten Collection).

Prüfen:

```bash
ls -l /home/lpalma/homelab/collections/ansible_collections/lpalma/dotfiles/roles/
```

Erwartete Ausgabe: `btop -> /home/lpalma/dotfiles/roles/btop`

### Workflow

1. Symlink auf die Rolle setzen, an der gearbeitet wird
2. Iterieren — jede Änderung in diesem Repo wirkt sofort in homelab
3. Wenn fertig: commit + push in diesem Repo
4. In homelab: `ansible-galaxy collection install --force` — löscht den Symlink und
   installiert die gepushte Version sauber
5. Für die nächste Rolle: neuen Symlink setzen

### Wichtig

- Der Symlink kann pro Rolle gesetzt werden — andere Rollen der Collection bleiben
  die stabile, installierte Version.
- `ansible-galaxy collection install --force` überschreibt Symlinks. Während der
  Entwicklung also nicht ausführen.
- Der Link-Name muss dem Rollennamen entsprechen, nicht dem Verzeichnisnamen im
  Quell-Repo.
