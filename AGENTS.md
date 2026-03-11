# AGENTS.md

Instructions in this file apply to every agent that modifies this repository.

## Scope

- This repository is a NixOS flake for the `mainframe` host.
- When a task changes the system configuration, agents must use this host target:
  `.#mainframe`

## Required Workflow After Reaching an Objective

- Treat an "objective" as the smallest complete unit of work that satisfies the user's request.
- Do not leave a completed objective uncommitted.
- Do not batch unrelated completed objectives into one commit.

Required order:

1. Implement the requested change until the objective is complete.
2. Create a git commit for that objective.
3. After the commit is created, activate the latest configuration:
   `nixos-rebuild switch --flake .#mainframe`

## Failure Handling

- If the commit fails, do not switch until the commit is successfully created.
- If `nixos-rebuild switch --flake .#mainframe` fails after a successful commit, report the failure clearly and include the failing command and error summary.

## Commit Expectations

- Each commit must correspond to one completed objective.
- Commit messages should state the user-visible intent of the change.
- Avoid mixing incidental cleanup with the main objective unless it is required for the change to work.

## Operational Notes

- Prefer showing the exact commands run in the final handoff.
- Prefer packages and inputs that are substitutable from the configured binary caches before accepting a local source build.
- If a ready-made binary package or upstream prebuilt release is available and appropriate, use that instead of a source-building package.
- Only choose a source build when no suitable cached or prebuilt option exists, or when the task explicitly requires building from source.
- If a task is documentation-only or otherwise cannot affect the built system, say that explicitly before skipping rebuild and switch steps.
