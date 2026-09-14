# GitHub automation

> **Maintainers only.** This folder operates the public me.os template. It is not an owner setup, migration, update, or private-repository mirroring guide.

GitHub `ck-os-vaults/me.os` is canonical. GitLab `ck-os-vaults/starter.os` is its read-only downstream backup mirror.

`workflows/gitlab-mirror.yml` mirrors every GitHub branch and tag to GitLab after a push, removes GitLab refs that no longer exist on GitHub, verifies exact parity, and runs hourly to catch Dependabot events that cannot access Actions secrets.

## One-time credential setup

1. In the matching GitLab project, open **Settings → Access tokens → Add new token**.
2. Create `github-actions-mirror` with the **Maintainer** role, an expiration date, and only the **write_repository** scope.
3. Copy the token once. Never put it in a file, command, commit, issue, or chat.
4. In the matching GitHub repository, open **Settings → Secrets and variables → Actions → Secrets → New repository secret**.
5. Name the repository secret `GITLAB_MIRROR_TOKEN` and paste the GitLab project token as its value.
6. Open **Actions → github-to-gitlab-mirror**, run it on `main`, and confirm the final step reports exact branch and tag parity.

If GitLab project access tokens are unavailable, stop rather than substituting a broader personal token. If a mirror run fails, fix it from GitHub and rerun it; do not push work directly to GitLab.
