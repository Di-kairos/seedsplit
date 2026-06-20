# Security Policy

seedsplit is a security tool — it splits a secret into shares and reconstructs
it, so its own correctness matters. A bug in the secret-sharing math or in how
shares are produced/parsed can silently destroy or expose a secret. If you find
a vulnerability, please report it responsibly.

## Reporting a vulnerability

**Do not open a public issue for an exploitable vulnerability.**

Use GitHub's private vulnerability reporting:

1. Go to the repository's **Security** tab → **Report a vulnerability**
   (<https://github.com/Di-kairos/seedsplit/security/advisories/new>).
2. Describe the issue, affected versions, and a reproduction if possible.

You'll get a response as soon as reasonably possible. Once a fix is ready, the
advisory is published and you'll be credited unless you prefer to stay anonymous.

## Scope

In scope:

- The **own crypto implementation**: Shamir Secret Sharing over GF(256) —
  the field arithmetic (log/antilog tables, multiply/divide/inverse), polynomial
  evaluation, and Lagrange interpolation in `split` / `combine`. A flaw that makes
  T-1 shares leak information about the secret, or makes T shares fail to
  reconstruct it exactly, is a real vulnerability.
- The integrity wrapper / share format (`SSS1-...`): a corrupted set or shares
  from different secrets must produce an **honest refusal**, never a wrong secret
  returned as if it were correct.
- Entropy handling: anything that weakens the randomness used for share
  coefficients (we read `/dev/urandom`; a regression that produces predictable or
  short reads is in scope).
- Secret exposure through the process: the secret must come from **stdin or
  `--file`**, never `argv`. A path that leaks the secret into `ps`/argv is in scope.
- Privilege or injection issues in the shell code (or the PowerShell port once it lands).

Out of scope:

- **Losing ≥(N-T+1) shares.** The threshold protects against leakage of fewer
  than T shares, but recovery is impossible once too many shares are gone. That
  is the documented premise (geography and media are your responsibility), not a bug.
- **Insecure storage or transport of the shares** themselves — plaintext shares
  written to a synced/backed-up location, sent over an insecure channel, etc. The
  shares are only as safe as where you store and distribute them (see the README
  *Scope & limitations*).
- **No SLIP-39 / hardware-wallet interoperability.** Full SLIP-39 (1024-word list
  + RS1024 + encryption) is a deliberate scope decision for a later pack, not a
  defect — the README states this plainly.

## Supported versions

The latest released version receives security fixes. seedsplit is pre-1.0;
older tags are not maintained.
