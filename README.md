# 🧪 aavi_sandbox

**aavi_sandbox** is a modular, overlay-based sandboxing framework for Linux systems.  
Created by [sneaks](https://jonathanderouchie.com) + Aavi, it lets you experiment boldly without touching your base system.  
Tinker, test, toggle, and time-travel — with layered control and full rollback.

---

## ✨ Features

| Command                      | Description |
|-----------------------------|-------------|
| `--play [name]`             | Start a named sandbox session. All system changes are redirected to an overlay. |
| `--commit [name]`           | Save sandbox changes to the base filesystem and create a snapshot for rollback. |
| `--clear`                   | Discard the current overlay session. No changes committed. |
| `--exit`                    | Gracefully unmount the overlay but preserve changes in the overlay (pause session). |
| `--enable [snapshot]`       | Apply a saved snapshot layer on top of the base system (non-destructive). |
| `--disable [snapshot]`      | Remove an enabled overlay layer from the active stack. |
| `--remove [snapshot]`       | Delete a snapshot and remove it from the index. Destructive. |
| `--list` / `--snapshots`    | View all named snapshots and overlays. |
| `--log`                     | Show command logs from `--play` sessions. |
| `--status`                  | Show overlay status, active layers, and pending changes. |
| `--undo [snapshot]`         | Roll back the system to a previous snapshot's backup (for committed overlays only). |
| `--ui` _(coming soon)_      | Launch an interactive terminal UI to manage overlays, commits, and snapshots. |

---

## 🛠 Installation

To install `aavi_sandbox` as a system-wide command:

```bash
make install
```

Manual method:

`sudo cp aavi_sandbox.sh /usr/local/bin/`

Once installed, run aavi_sandbox from anywhere like a command-line spell 🔮


## ⚠️ Root Access & System Paths

`aavi_sandbox` is designed to interact with system-level directories like:

- `/etc`
- `/opt`
- `/var/lib`

This means:

- You should run most commands with `sudo`
- Especially for `--play`, `--commit`, `--enable`, and `--undo`
- Without proper permissions, overlays may fail to apply or changes won't be committed

If you're testing in user space (e.g. `~/sandbox_test`), you can override the default paths:

```ini
# ~/.aavi_sandbox.conf
LOWERDIR=/home/jojo/sandbox_test
UPPERDIR=/tmp/aavi_overlay/sandbox_test
MOUNTPOINT=/home/jojo/sandbox_test
```

This is perfect for dev/test environments where root access isn't available—or just to keep things clean.

---

## 🧵 Example Workflow

```bash
# Start a named sandbox session
sudo aavi_sandbox --play ha_darkmode_patch

# Make changes (these go to the overlay, not your real system)
nano /etc/homeassistant/configuration.yaml

# Save the session changes permanently
sudo aavi_sandbox --commit ha_darkmode_patch

# Or discard the session without committing
sudo aavi_sandbox --clear
```

---

## 🧱 Overlay Layering (Patch Stack)

```bash
sudo aavi_sandbox --enable ha_darkmode_patch
sudo aavi_sandbox --enable iot_debug_tools
```

You can stack multiple overlays to test combinations of patches without touching your lower system.

```bash
sudo aavi_sandbox --disable ha_darkmode_patch
```

---

## 🔧 Command Logging

Every `--play` session records all shell commands in:
```
/var/log/aavi_sandbox_sessions/
```
If you reboot without committing, the overlay is lost but the log remains.

---

## 📚 Snapshot Management

```bash
sudo aavi_sandbox --list
sudo aavi_sandbox --remove my_old_patch
```

---

## 🧪 Coming Soon

- `--diff` support
- `--ui` terminal toggler
- Multi-directory sandbox layers
- Tagged snapshot indexing
- `sandbox.yaml` metadata schema

---

## 🧡 Authors

Built with curiosity and chaos by:

- [Jonathan DeRouchie (sneaks)](https://github.com/sneaks)
- Aavi, your filesystem muse

---

## 🛡 License

Soulware-friendly MIT license.  
Use freely, break gently, document your magic.