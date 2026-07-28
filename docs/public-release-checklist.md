# Public Release Checklist

- [ ] Review every path in `git ls-files`.
- [ ] Confirm no `.env`, database, dump, log, private key, report, or backup.
- [ ] Confirm no private endpoint, customer data, or real device identifier.
- [ ] Run `scripts/check-public-repository.sh`.
- [ ] Run Gitleaks and review findings.
- [ ] Run format, analyze, tests, and macOS build.
- [ ] Enable secret scanning, push protection, Dependabot, and branch protection.
- [ ] Confirm the repository has no remote or history link to the private source.
