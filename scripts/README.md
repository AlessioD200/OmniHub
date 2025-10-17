# Deploy scripts

deploy_to_rpi.sh — push local branch and update code on a Raspberry Pi via SSH.

Usage examples

1) Using environment variables:

```bash
export RPI_HOST=pi@raspberry.local
export RPI_PATH=/home/pi/OmniHub
export RPI_SERVICE=homehub.service   # optional
./scripts/deploy_to_rpi.sh
```

2) Using flags:

```bash
./scripts/deploy_to_rpi.sh --host pi@raspberry.local --path /home/pi/OmniHub --branch main --service homehub.service
```

Notes and recommendations
- Ensure you have SSH key-based login set up for the `RPI_HOST` user. The script uses `ssh` non-interactively for automated runs.
- The script will `git push origin <branch>` from your machine — make sure you want to push local commits.
- On the remote side the script will `git reset --hard origin/<branch>`; any uncommitted changes on the Pi will be lost.
- The script looks for `requirements.txt` and will create/activate `.venv` and install deps.
- If a systemd service is provided (`RPI_SERVICE`) the script will attempt to `sudo systemctl restart` it; the remote account must have sudo rights.

GitHub Actions (CI) integration
--------------------------------

A workflow file `.github/workflows/deploy-to-rpi.yml` has been added to allow automatic deployment when pushing to `main`.

Required repository secrets (set these in Settings → Secrets → Actions):

- `SSH_PRIVATE_KEY` — the private key for an SSH user that can access the Raspberry Pi (the corresponding public key must be in the Pi's `~/.ssh/authorized_keys`).
- `RPI_HOST` — the SSH host string, e.g. `pi@raspberry.local` or `pi@1.2.3.4`.
- `RPI_PATH` — the path to the repository on the Pi, e.g. `/home/pi/OmniHub`.
- `RPI_SERVICE` — (optional) systemd service to restart after deploy, e.g. `homehub.service`.

How the workflow works
- On push to `main`, the workflow SSHs to `RPI_HOST`, `cd` into `RPI_PATH`, fetches and resets to the pushed branch, installs Python deps into `.venv` if `requirements.txt` exists, and restarts the specified `RPI_SERVICE` if provided.

Security notes
- The workflow uses an SSH key stored in repository secrets. Keep the private key limited to the deployment user and rotate keys if needed.
- For production use consider restricting the SSH key to specific commands via `authorized_keys` or using additional safety checks on the remote side.

