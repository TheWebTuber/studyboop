# CampusBoop v1.1.1 website deployment

Upload the **contents of this folder/ZIP directly to the root** of the GitHub Pages repository for `campusboop.creatorpromote.com`.

The repository root should contain:

- `index.html`
- `styles.css`
- `app.js`
- `install-campusboop.sh`
- `install-campusboop.ps1`
- `CNAME`
- `.nojekyll`
- `assets/`
- `downloads/`

Do not place everything inside an extra `CampusBoop-v1.1.1.../` folder in the repository.

The Linux quick installer automatically chooses x64 or ARM64 based on `uname -m` and verifies the release SHA-256 before installing.
