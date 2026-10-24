# Contributing to Datadog Kubernetes Observability Lab

Thank you for your interest in contributing to this project! 🚀

This repository is designed as a clean, production-grade, and beginner-accessible educational lab. To maintain stability, quality, and security, we follow structured versioning best practices and enforce branch protection.

---

## 🌳 Branching Strategy & Governance

We follow a modified GitFlow / GitHub Flow model with strict branch protection on production branches:

```
[ feature/* or fix/* ] ──(commit)──> [ develop ] ──(PR + Admin Review)──> [ main (protected) ]
```

### 1. `main` (Protected)
* **Status**: 🔴 **Protected Branch** (Production-ready & stable release).
* **Direct pushes (`git push origin main`) are strictly FORBIDDEN and blocked by GitHub.**
* Any change to `main` **must** arrive through a **Pull Request (PR)**.
* **Requirements to merge into `main`:**
  1. Minimum 1 approving review from the repository Administrator (`@araujoajoao`).
  2. All automated CI checks in `.github/workflows/validate.yml` must pass green (`Terraform Format & Validate`, `YAML Lint`, `ShellCheck`).
  3. Branch must be up-to-date with `main` before merging (`strict` check).
  4. All conversation review comments must be resolved.
  5. Force pushes (`--force`) and branch deletions are completely blocked.

### 2. `develop` (Integration)
* **Status**: 🟡 Staging & integration branch.
* Used to test combined features and configurations before promoting to `main`.
* Feature branches can be merged into `develop` for validation.

### 3. `feature/*` and `fix/*` (Working Branches)
* **Status**: 🟢 Ephemeral development branches.
* Always branch off `develop` (or `main` for hotfixes):
  * `feature/<short-description>`: New capabilities, applications, or observability signals.
  * `fix/<short-description>`: Bug fixes, linter corrections, or configuration adjustments.
  * `docs/<short-description>`: Documentation additions or guide updates.

---

## 🛠️ Step-by-Step Contribution Workflow

### Step 1: Clone and Create a Feature Branch
Do not work directly on `main`. Start by syncing with `develop` and creating a branch:

```bash
# 1. Update your local develop branch
git checkout develop
git pull origin develop

# 2. Create your feature branch
git checkout -b feature/my-new-feature
```

### Step 2: Implement Your Changes & Validate Locally
Before committing, make sure all automated linters and validation suites pass locally:

```bash
# Validate Terraform formatting and syntax
cd terraform
terraform fmt -check
terraform validate
cd ..

# Validate Kubernetes and Datadog YAML manifests
yamllint -d '{extends: default, rules: {line-length: {max: 500}, document-start: disable, indentation: disable}}' \
  configmap/ app/ builds/ kubernetes/

# Validate shell scripts
shellcheck populate.sh scripts/*.sh
```

### Step 3: Commit with Conventional Commits
Write atomic, well-described commits using [Conventional Commits](https://www.conventionalcommits.org/):

```bash
git commit -m "feat(agent): update datadog helm chart values for SSI"
```

#### Commit Prefixes:
* `feat:` — New feature, service, or instrumentation capability
* `fix:` — Bug fix, syntax fix, or configuration correction
* `docs:` — Documentation only (`README.md`, `deploy-guide.md`, `GLOSSARY.md`)
* `refactor:` — Code restructure without behavioral changes
* `style:` — Whitespace, formatting, indentation (no production code change)
* `chore:` — Repository maintenance, dependency updates, scripts
* `ci:` — Changes to CI workflows (`.github/workflows/validate.yml`)

### Step 4: Push to Your Remote Branch
Push your branch to GitHub:

```bash
git push -u origin feature/my-new-feature
```

### Step 5: Open a Pull Request & Request Admin Review
1. Navigate to GitHub and open a **Pull Request** targeting `main` (or `develop`).
2. Provide a clear description:
   * **What** changed?
   * **Why** was this change made?
   * How did you test it?
3. **Assign and request review from the Admin (`@araujoajoao`)**.
4. Automated GitHub Actions (`Validate`) will execute:
   * Terraform Format & Validate
   * YAML Lint
   * ShellCheck
5. If changes are requested, push additional commits to your branch.
6. Once approved by the Administrator and all checks are green, the PR will be merged into `main`!

---

## 🔒 Security & Secrets Policy

> [!CAUTION]
> **NEVER commit secrets, API keys, or personal credentials.**

Before submitting a PR, verify:
* `.env` is NOT tracked in git (it must remain in `.gitignore`).
* No real Datadog API keys, App keys, tokens, or private keys are committed in YAMLs or scripts.
* Use placeholders (`YOUR_API_KEY`, `YOUR_APP_KEY`) in documentation or examples.
* State files (`*.tfstate`, `.terraform/`) must never be committed.

---

## 🤝 Code of Conduct

* Be respectful, welcoming, and constructive.
* Help newcomers learn Kubernetes, observability, and Datadog.
* Prioritize clarity and simplicity for first-time learners.
