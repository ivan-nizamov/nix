# Rebuild Leases

`rebuild build` is unprivileged and can always be used for iteration.

`rebuild test` and `rebuild switch` require a short-lived
lease. This prevents permanent passwordless root-equivalent rebuild access while
still letting agents fix small build errors quickly.

## Commands

```sh
rebuild-authorize 10m
rebuild status
rebuild switch
rebuild revoke
```

The authorize command prompts for the normal `iva` sudo password and creates a
root-owned lease under `/run`. The lease expires automatically and is capped at
30 minutes by `local.rebuild.lease.maxSeconds`.

Agents may run `test` or `switch` only while the lease is active. Revoke the
lease when the agent should lose rebuild access immediately.

From another trusted device:

```sh
ssh mainframe-iva 'rebuild-authorize 10m'
```
