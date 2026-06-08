---
name: authoring-api-endpoints
title: Authoring API Endpoints
description: How to add one REST/JSON:API command endpoint (create/update/destroy) as a vertical slice - the layers:api_endpoint scaffold generates the container use case + form and the engine story, controller, serializer, route, registration, and specs; you fill the semantics. Use when adding a REST write endpoint to an api engine.
category: architecture
status: active
version: 1.0
applies_to:
  - Ruby
  - Rails
  - JSON:API
  - Layers
priority: REQUIRED
triggers:
  - new rest endpoint
  - api endpoint
  - json api create
  - add a controller action
anti_triggers:
  - graphql endpoint
  - a read/index/show endpoint
  - business logic internals
user_invocable: true
last_reviewed_at: 2026-06-08
---


# Authoring API Endpoints

A REST/JSON:API **command** endpoint (create/update/destroy) is a vertical slice across
the container and an api engine. Never hand-create the files — generate the whole slice:

```bash
bin/rails generate layers:api_endpoint orders/create --engine v1
```

then fill the TODOs. The scaffold settles placement and wiring so you never re-derive
where anything goes; you supply the semantics.


## Required Reading

```text
common_agent_skills/derisk_layers/authoring-engines/SKILL.md
common_agent_skills/derisk_layers/authoring-use-cases/SKILL.md
common_agent_skills/derisk_layers/authoring-controllers/SKILL.md
```

Supporting references in this skill:

```text
references/annotated-slice.md   # every generated file, annotated
references/checklist.md         # fill-in checklist
```

Reads (index/show) are **not** this scaffold: they are CQS-separate — a query object
resolved through the engine registry, rendered by a serializer, no command path. See
[[authoring-controllers]] and [[authoring-query-objects]].


## What the slice is

The crossing obeys ruling 15/16 — the engine names no container constant; everything
container-side is reached through the registry:

```text
controller (engine)              thin; forwards permitted raw params + current_authorization
   │  names its engine sibling story (engine-owned — allowed)
   ▼
user story (engine)              the fast exit; resolves the use case via the registry
   │  Engine.configuration.use_cases[:resource_action]
   ▼
use case (container)             the business operation; builds its form peer, persists
   │  reaches Forms::… (a container peer)
   ▼
form (container)                 validation + persistence-shaping
```

The serializer (engine) renders the success payload; the route (engine) exposes the
action; the engine initializer (container) binds the use case into the registry.


## What the scaffold generates

| File | Home | You fill in |
| --- | --- | --- |
| use case | `app/lib/use_cases/<domain>/<action>.rb` | raw inputs, persistence in `execute!` |
| form | `app/lib/forms/<domain>/<action>_form.rb` | accessors, validations, builders, whitelist |
| user story | `apis/<engine>/app/lib/user_stories/<engine>/<domain>/<action>.rb` | the raw inputs forwarded to the use case |
| controller (+action) | `apis/<engine>/app/controllers/<engine>/<resource>_controller.rb` | permitted params |
| serializer | `apis/<engine>/app/serializers/<engine>/<resource>_serializer.rb` | exposed attributes |
| route | `apis/<engine>/config/routes.rb` | (injected) |
| registration | `config/initializers/<engine>.rb` | (injected) |
| request + routing specs | `apis/<engine>/spec/...` | the pending cases ([[testing-rails-requests]], [[testing-routing]]) |


## Rules

- One invocation per command endpoint. Re-run for each action on a resource; the
  controller is created once, then the action is injected.
- The engine half names no container use case, query, form, or model — story resolves
  the use case via the registry; the use case (container) owns the form
  ([[authoring-use-cases]], ruling 16).
- Authorization is the credential's scope, applied in the story's lookups — not a flag
  check in the controller ([[api-authentication-authorization]]).
- The serializer needs `jsonapi-serializer`; the controller's `render_json_api` /
  `render_json_api_errors` come from the engine's base controller concern.


## Avoid

- hand-creating any slice file — generate, then fill.
- a controller that builds a form or names a use case (ruling 15/16).
- routing a read through this scaffold — reads are query objects + serializers.
