# AGENTS.md

Instructions in this file apply to every agent that modifies this repository.

## Scope

- This repository is a NixOS flake tracked with one deployment branch per host:
  - `mainframe`: the IPv6-only server, using `.#mainframe`.
  - `thinkpad`: the ThinkPad laptop, using `.#thinkpad`.
  - `legion`: the previous Legion laptop, using `.#legion`.
- Host-specific work belongs on that host's branch. Shared module work should be
  committed on the host branch that needs it first, then deliberately merged or
  cherry-picked to other host branches when those hosts should receive it.
- When a task changes the system configuration, agents must switch every host
  branch that received the completed objective before handing off the work.

## Required Workflow After Reaching an Objective

- Treat an "objective" as the smallest complete unit of work that satisfies the user's request.
- Do not leave a completed objective uncommitted.
- Do not batch unrelated completed objectives into one commit.
- A change is not complete until the latest committed configuration has been
  switched successfully on every affected host branch.

Required order:

1. Implement the requested change until the objective is complete.
2. Create a git commit for that objective.
3. After the commit is created, activate the latest configuration for every
   affected host branch. Examples:
   `sudo nixos-rebuild switch --flake .#thinkpad`
   `ssh -t mainframe-iva 'zsh -ic nrs'`
4. Only hand off the work after the switch succeeds.

## Failure Handling

- If the commit fails, do not switch until the commit is successfully created.
- If any required switch fails after a successful commit, the objective is still incomplete.
- In that case, keep working until the switch succeeds. Create additional commit(s) as needed for the fix, then retry the switch.
- Do not treat `nixos-rebuild build`, `nixos-rebuild test`, or any other non-switch step as completion unless the user explicitly asked for that instead.

## Commit Expectations

- Each commit must correspond to one completed objective.
- Commit messages should state the user-visible intent of the change.
- Avoid mixing incidental cleanup with the main objective unless it is required for the change to work.

## Operational Notes

- Prefer showing the exact commands run in the final handoff.
- Prefer packages and inputs that are substitutable from the configured binary caches before accepting a local source build.
- If a ready-made binary package or upstream prebuilt release is available and appropriate, use that instead of a source-building package.
- Only choose a source build when no suitable cached or prebuilt option exists, or when the task explicitly requires building from source.
- Do not skip the switch step just because a change looks documentation-only; if
  a host branch was modified, finish by switching the latest committed
  configuration for that host branch.
