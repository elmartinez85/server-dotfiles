# Roadmap: server-dotfiles

## Milestones

- ✅ **v1.0 Server Bootstrap MVP** — Phases 1–3.1 (shipped 2026-02-23)
- 🚧 **v1.1 Security and Maintenance** — Phase 4 (planned)

## Phases

<details>
<summary>✅ v1.0 Server Bootstrap MVP (Phases 1–3.1) — SHIPPED 2026-02-23</summary>

- [x] Phase 1: Foundation (3/3 plans) — completed 2026-02-22
- [x] Phase 2: Shell Environment and Config Deployment (2/2 plans) — completed 2026-02-22
- [x] Phase 3: CLI Tools and Docker (4/4 plans) — completed 2026-02-22
- [x] Phase 3.1: Shell Installer Robustness (1/1 plan, INSERTED) — completed 2026-02-23

Full details: `.planning/milestones/v1.0-ROADMAP.md`

</details>

### 🚧 v1.1 Security and Maintenance (Planned)

- [ ] **Phase 4: Security and Maintenance** — SSH hardening, fail2ban, UFW firewall, and automated version updates

#### Phase 4: Security and Maintenance
**Goal**: The server rejects all SSH password authentication attempts and brute-force attacks, the firewall enforces default-deny inbound policy, and pinned tool versions are tracked in a single file with automated update PRs
**Depends on**: Phase 3
**Requirements**: SEC-01, SEC-02, SEC-03, SEC-04, SEC-05, SEC-06, MAINT-02
**Success Criteria** (what must be TRUE):
  1. SSH login with the configured public key succeeds; SSH login with a password is rejected
  2. SSH root login is rejected
  3. fail2ban is running and its status shows the sshd jail is active
  4. UFW status shows default-deny inbound with SSH explicitly allowed, and SSH connections work through the firewall
  5. All pinned tool versions are defined in a single `versions.sh` file and Renovate Bot is configured to open PRs for new releases
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation | v1.0 | 3/3 | Complete | 2026-02-22 |
| 2. Shell Environment and Config Deployment | v1.0 | 2/2 | Complete | 2026-02-22 |
| 3. CLI Tools and Docker | v1.0 | 4/4 | Complete | 2026-02-22 |
| 3.1. Shell Installer Robustness | v1.0 | 1/1 | Complete | 2026-02-23 |
| 4. Security and Maintenance | v1.1 | 0/TBD | Not started | — |
