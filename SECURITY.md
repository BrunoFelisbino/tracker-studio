# Security Policy

## Reporting a vulnerability

Do not open public issues containing credentials, customer data, device identifiers, private endpoints or exploit details.

Report security findings privately to the repository owner through GitHub's private vulnerability reporting feature. Include affected version, reproduction steps, impact and a suggested mitigation when available.

## Secrets policy

- Never commit `.env`, database URLs, API tokens, private keys or production device credentials.
- Client applications must not contain privileged backend secrets.
- Use `.env.example` only for variable names and safe placeholders.
- Rotate any credential immediately after accidental exposure; deleting a file does not remove it from Git history.
- Test fixtures must use synthetic IMEI, ICCID, phone numbers, coordinates and customer data.

## Before making the repository public

1. Rotate any credential that may have existed in the private source repository.
2. Confirm this repository has a single clean initial commit.
3. Run secret scanning against the complete history.
4. Review assets, manuals and command catalogs for redistribution rights.
5. Confirm that logs, reports, screenshots and fixtures contain no real customer or device data.
