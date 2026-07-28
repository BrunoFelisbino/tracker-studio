# Public Security Audit

Audit source: `refactor/open-source-plugin-foundation` from the private
repository. The public tree was assembled in a separate temporary directory
and initialized with a new Git repository.

| File or scope | Risk | Severity | Finding (masked) | Action | Decision |
| --- | --- | --- | --- | --- | --- |
| `lib/core/config/env.dart` | Private Supabase URL | Critical | `https://***.supabase.co` | Removed fixed default and replaced with empty generic setting | Excluded |
| `lib/features/sessions/presentation/tracker_studio/localitel_client.dart` | Private integration and auth header | Critical | LocaliTel endpoint and `Bearer ***` | Made endpoint generic, optional, and user-configurable | Replaced |
| `assets/erbs_database.sqlite` | Local operational database | Critical | SQLite database | Deleted from public tree | Excluded |
| `package.json`, `prisma.config.ts` | Private backend/database tooling | High | Prisma and `DATABASE_URL` reference | Deleted; public app uses local storage only | Excluded |
| Tests and catalogs | Operational domains and identifiers | High | `***.goodscare.com.br`, `agps.***` | Must use reserved examples before release | Pending manual review |
| `.env` and generated files | Credentials/build output | Critical | Values not reproduced | Excluded by allowlist and `.gitignore` | Excluded |

No complete secret is reproduced in this report. Any credential that was ever
valid in the private repository must be rotated independently; deleting it
from this new repository does not rotate it.

## Remaining Manual Gate

Before publication, review every file returned by `git ls-files`, especially
manuals, images, PDFs, generated catalogs, fixtures, and command examples.
Do not publish if any real customer, device, endpoint, or credential remains.
