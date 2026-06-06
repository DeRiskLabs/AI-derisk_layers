---
name: authoring-layers-jobs
title: Authoring Jobs with Layers
description: The layers overlay on job authoring - Layers::BaseJob declares its use case, performs with the job as listener, maps failure to JobFailed for queue retry, and may declare fire_and_forget. Use when writing jobs in an application using the layers gem.
category: architecture
status: active
version: 1.0
applies_to:
  - Ruby
  - Rails
  - Layers
priority: REQUIRED
triggers:
  - layers job
  - BaseJob
  - fire_and_forget
  - job calls use case
anti_triggers:
  - generic job conventions (see derisk_rails authoring-jobs)
user_invocable: true
last_reviewed_at: 2026-06-06
---


# Authoring Jobs with Layers

A job is a **command caller**: it defers one public command and maps the outcome to
queue semantics. `Layers::BaseJob` makes that declarative.


## Required Reading

```text
common_agent_skills/derisk_rails/authoring-jobs/SKILL.md
common_agent_skills/derisk_rails/testing-jobs/SKILL.md
```


## The Shape

```ruby
module Members
  class SyncProfileJob < ApplicationJob
    include Layers::BaseJob

    use_case 'use_cases/members/sync_profile'
  end
end
```

- `use_case '...'` names the command by string (constantized at perform time; a
  missing or non-constantizable name raises `InvalidUseCase`).
- `perform(**args)` runs the use case with **the job as listener**; the use case's
  `success`/`failure` double-dispatch to the job's `on_success`/`on_failure`.
- The default `on_failure` raises `Layers::JobFailed`, with messages extracted per
  the failure contract (the payload's `.errors` object or errors collection) — so
  **queue retry engages by default**.
- The default `on_success` is a no-op. Override `on_failure` for discard semantics;
  override `on_success` for follow-up side effects (rarely needed).
- `call_use_case(**args)` is the private seam `perform` delegates through — override
  it to adapt arguments, not `perform`.


## fire_and_forget

```ruby
class AuditPingJob < ApplicationJob
  include Layers::BaseJob

  use_case 'use_cases/audit/ping'
  fire_and_forget
end
```

Per-class like every layers declaration: the use case runs with **no listener** —
no raise, no retry, whatever the outcome. For genuinely best-effort work only; if a
failure should ever be retried or noticed, it is not fire-and-forget.


## Rules

- Jobs carry kwargs of primitives/uuids; the use case re-fetches records fresh
  (through its queries or repositories) at perform time.
- Idempotency lives in the use case's guards — the job adds none of its own logic.
- Observers may enqueue jobs; that is the house route for async side effects:
  observer → job → use case.
- A job never calls a user story; it is not a user interaction.
- All declarations are per-class: nothing inherits `use_case` or `fire_and_forget`.


## Testing the Overlay

On top of [[testing-jobs]]:

- Perform side: stub the use case class; assert it received `call` with the
  deserialized kwargs and `listener: job`.
- Failure mapping: a `failure` callback with the default `on_failure` raises
  `Layers::JobFailed` carrying the contract's error messages — pin that when the
  job relies on retry.
- `fire_and_forget`: pin that perform neither raises nor wires a listener.
