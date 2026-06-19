# Contributing to Datadog Kubernetes Observability Lab

Thanks for your interest in contributing! 🚀

## How to Contribute

1. **Fork** the repository
2. **Create a branch** for your change:
   ```bash
   git checkout -b feat/my-improvement
   ```
3. **Make your changes** and ensure they work:
   - Run `terraform fmt -check` in the `terraform/` directory
   - Run `terraform validate` in the `terraform/` directory
   - Verify Kubernetes manifests with `kubectl apply --dry-run=client -f <file>`
   - Run `shellcheck` on any shell scripts
4. **Commit** with a clear message:
   ```bash
   git commit -m "feat: add X to improve Y"
   ```
5. **Open a Pull Request** with a clear description of what changed and why

## Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` — new feature or capability
- `fix:` — bug fix
- `docs:` — documentation changes only
- `style:` — formatting, whitespace, emojis
- `refactor:` — code change that neither fixes a bug nor adds a feature
- `chore:` — maintenance, dependencies, cleanup
- `security:` — security-related changes

## Code of Conduct

- Be respectful and constructive
- Focus on what is best for the lab and the community
- Welcome newcomers and help them learn
