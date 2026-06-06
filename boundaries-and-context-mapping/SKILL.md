---
name: boundaries-and-context-mapping
title: Boundaries and Context Mapping
description: How to decide where bounded-context boundaries go in a component-based Rails monolith, recognize a context that has overgrown or been carved too fine, and map how contexts relate. Use when splitting or merging contexts, extracting a context from the main app, or deciding what owns a new piece of domain.
category: architecture
status: active
version: 1.1
applies_to:
  - Ruby
  - Rails
  - Layers
priority: REQUIRED
triggers:
  - where should this boundary go
  - split a context
  - context too big
  - extract a bounded context
  - context map
  - what owns this
anti_triggers:
  - choosing a layer object within a known context
  - building a component or engine whose boundary is already decided
user_invocable: true
last_reviewed_at: 2026-06-06
---


# Boundaries and Context Mapping

Where boundaries go is **the architect's judgment call**. This skill gives the inputs
to that judgment and the discipline around it — it is not an algorithm. The hard rule
for agents: **when boundary placement is ambiguous, ask the architect. Never invent a
boundary silently.**


## Required Reading

```text
common_agent_skills/derisk_ruby/object-oriented-boundaries/SKILL.md
common_agent_skills/derisk_layers/rails-app-architecture/SKILL.md
```

Supporting references in this skill:

```text
references/smells.md      # overgrown and over-fine catalogues, with responses
references/checklist.md   # the judgment questions
```

Packaging a decided boundary: [[authoring-components]] (the three-homes table) or
[[authoring-engines]]. Crossing mechanics: [[cross-context-communication]].


## The Monolith's Named Scales

Bounded contexts are fractal (see object-oriented-boundaries); this architecture
names four scales of them:

```text
a layer object                       # use case, query object, form
a domain cluster in app/lib          # a namespace of layer objects
a slice: component / engine / api    # an unbuilt gem with a hard boundary
the application                      # one bounded context to its users
```

A boundary decision is usually about the third scale: when does a domain cluster
deserve a slice, and which home does it get. The home question is settled by the
three-homes table in [[authoring-components]]; *this* skill is about whether and
where to draw the line at all.


## Judgment Inputs

In rough priority order — inputs, not rules:

1. **One business concept.** A context's one thing should be nameable without "and":
   *everything to do with user registration* qualifies, however many files it takes.
2. **Language shift.** When the same word means different things ("account" to
   identity vs to billing), you are looking at two contexts.
3. **Change-together clusters.** Code that always changes in the same commit belongs
   inside one boundary; code that never changes together is a candidate for two.
4. **The context-window test.** A context is right-sized when a human+agent pair can
   hold its code and specs in context at once and work accurately. Too big to hold
   is too big — full stop.
5. **Delivery is not domain.** How something is served (REST, GraphQL, HTML) never
   defines a domain boundary. Delivery slices live in `apis/`; the domain rules they
   call gravitate to components.


## Composition: Decomposing Without Telling Anyone

A context that grows heavy is decomposed **inside its boundary** — the decomposition
is an implementation detail to every outside caller.

The canonical case: `apis/` as a whole is one bounded context — *all of the user
interactions with the application*. When it gets unwieldy, it decomposes into
multiple engines (one for everything auth, another for the remaining resources);
mounting recombines them, and to every API client there is still exactly one set of
APIs. Nothing outside the boundary changed.

The same move works at every scale: registration may internally become role
management + authentication + authorization, and remain `registration` to callers.
If a split forces callers to change, it was a boundary break, not a decomposition.


## Contexts Own Behaviour, Not Tables

The container application owns all ActiveRecord models. A context's ownership is of
**behaviour over** the models it reaches:

- A component declares the repositories it needs; the container registers model
  classes into them at boot; the component sends them messages and owns the rules.
- The same model registered into two components' registries is fine — each gets its
  own duck-typed view of shared substrate.
- Two contexts writing the same columns *under their own competing rules* is a
  boundary smell: one of them owns that behaviour; find which.


## Cross-Context Referencing

What may cross a boundary (mechanics in [[cross-context-communication]]):

- Messages to the target context's public interface — nothing else. Commands carry
  the caller (or its delegate) as listener; queries return the answer directly
  (see [[cross-context-communication]]).
- Identities cross as uuids (or whole duck-typed objects); never another context's
  internal constants.
- Consumers are clients: a consumer needing different behaviour requests a boundary
  change from the context's owner (even when that is the same person). The boundary
  grows and is tested on its own side; crossings are validated by the interaction
  owner's delivery-level specs.


## The Context Map Lives in READMEs

There is no separate map document to go stale. Each slice's README states its
contract at the door:

- what it owns (the business concept),
- what it exposes (the public interface),
- what it consumes (which contexts' interfaces),
- what it registers (for components: the repositories the container must fill).

Reading the READMEs of `components/`, `engines/`, and `apis/` *is* reading the
context map.


## Extraction Paths

- **Main app → slice**: when a domain cluster in `app/lib` starts meeting the
  judgment inputs above (own vocabulary, changes together, holdable as a unit),
  carve it out — component if no Rails abstractions, engine otherwise.
- **Engine → component**: when an engine's Rails abstractions fall away (views gone,
  jobs moved), what remains is pure domain — repackage it under `components/`.
- Either way the move is interface-first: stand up the public interface, route
  callers through it, then relocate the internals behind it.


## Avoid

- Inventing a boundary without the architect's sign-off.
- Splitting by technical layer ("all the validators") — boundaries follow business
  concepts, not file types.
- A split that changes callers — decomposition is invisible or it is wrong.
- Merging two contexts to avoid defining a contract between them.
- Letting delivery protocol decide domain shape.
