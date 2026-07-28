#!/usr/bin/env bash
set -euo pipefail

forbidden='(^|/)(\.env($|\.)|.*\.(db|sqlite|sqlite3|dump|log|bak|pem|key|p12|pfx|jks|keystore|zip))'
if git ls-files | rg -i "$forbidden"; then
  echo 'Forbidden file detected' >&2
  exit 1
fi

if rg -n -i 'localitel\.com\.br|goodscare\.com\.br|supabase\.co|postgres(ql)?://|mongodb://|redis://|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|DATABASE_URL\s*=\s*[^[:space:]]+' . --glob '!docs/public-security-audit.md' --glob '!scripts/check-public-repository.sh' --glob '!.git/**' --glob '!**/.dart_tool/**' --glob '!**/build/**'; then
  echo 'Private endpoint or credential pattern detected' >&2
  exit 1
fi

echo 'Public repository checks passed'
