---
name: cross-context-communication
title: Layers Cross-Context Communication
description: Layers-specific mechanics of crossing a bounded-context boundary - commands via the use-case pattern with listener callbacks, queries as side-effect-free asks returning the answer itself. Use in a Layers-based Rails app when one context calls another, when designing a context's public interface, or when evolving a boundary contract.
category: architecture
status: active
version: 1.2
applies_to:
  - Ruby
  - Rails
  - Layers
priority: REQUIRED
triggers:
  - call another context
  - cross a boundary
  - public interface method
  - boundary contract
  - command or query
anti_triggers:
  - work entirely inside one context
  - deciding where a boundary goes
user_invocable: true
last_reviewed_at: "2026-10-01"
---


# Cross-Context Communication

This is the Layers implementation of [[cross-boundary-communication]].

Every crossing of a bounded-context boundary is one of two things:

| | Command | Query |
| --- | --- | --- |
| What it is | A fallible operation with named outcomes; usually changes state | Side-effect-free ask with no domain-failure outcome |
| Protocol | Use-case pattern: message + listener; outcome via `success`/`failure` callbacks | Plain return value |
| Returns | Never used | The answer itself: an enumerable (possibly empty, never nil) for collection questions; the object or nil for explicitly singular ones |
| Failure | The `failure` callback, payload carrying `.errors` | Absence is not failure (nil/empty); infrastructure exceptions propagate |

Everything then acts like a call stack — a good impedance match between user requests
and how they are handled. No wrapper objects in either direction: a query returns the
domain answer itself, never an object carrying success/failure semantics.


## Fallible In-Memory Operations

An operation may be a command even when it does not persist state. Use the command
protocol when performing the operation can produce an **expected domain failure** that
must cross the boundary with structured errors.

For example, assembling an immutable domain model from validated input can still fail
semantic validation:

```ruby
ontology_assembler.call(
  definitions: definitions,
  listener: self,
  on_success: :ontology_assembled,
  on_failure: :ontology_invalid
)
```

This is a narrow exception to the usual state-changing command rule. Do not turn an
ordinary side-effect-free lookup or calculation into a command merely because it might
raise an infrastructure or programming exception. The deciding question is whether
**expected domain invalidity is part of the public protocol** and needs a named failure
outcome.


## Required Reading

```text
[[cross-boundary-communication]]
[[object-oriented-boundaries]]
[[boundaries-and-context-mapping]]
```

Supporting references in this skill:

```text
references/annotated-example.md   # one full crossing, both sides, command and query
references/checklist.md           # crossing checklist
```


## Commands

### The caller's side

Send the message named by the contract through a callable boundary dependency, with the
caller (or its delegate) as listener; implement the callbacks the contract declares:

```ruby
account_registrar.call(form: form, listener: self)
```

- Callers come in four kinds: a user story orchestrating, a job deferring, another
  context's use case, and **an operator in the console** — the console is a delivery
  adapter too; effect change by sending public commands, never raw model writes.
- The callbacks receive the declared keyword payloads (`success(identity:)`,
  `failure(form:)`); a failure payload always carries the means to render errors.
- Never use a command's return value. The outcome arrives as a message or not at all.

### The caller's dependency seam

Keep resolution of the neighbouring component out of the operation itself. Until the
application has enough examples to justify a boot-filled registry, expose the public root
message as a callable behind a private role-named method:

```ruby
def account_registrar
  @account_registrar ||= Accounts.public_method(:register_identity)
end
```

The use case depends on the callable protocol (`#call`), not on the neighbour constant
throughout its behaviour. Later, the same private method can resolve a callable registered
at boot without changing `#call` or its spec. Do not introduce a registry before repeated
crossings establish the useful registration shape.

### The callee's side

- The root-constant method is a thin pass-through to a use case. This public method is
  the boundary-crossing protocol:

  ```ruby
  module Accounts
    def self.register_identity(*args, **opts)
      Accounts::UseCases::RegisterIdentity.call(*args, **opts)
    end
  end
  ```

- The use case declares its outputs with `emits success: [...], failure: [...]` —
  the contract is enforced at both ends: emitted payloads must match exactly, and
  the wired listener's callbacks are verified at construction.
- Payload keys are stable and meaningful; they ARE the contract.


## Queries

Side-effect-free, full stop — a query that creates-if-missing, touches a timestamp,
or memoizes into the database is a command wearing a disguise, and it erodes the
whole split.

```ruby
Accounts.profiles_for(identity_uuid: uuid)   # => enumerable, possibly empty, never nil
Accounts.profile(uuid: uuid)                 # => the profile, or nil
```

- Collection questions return an enumerable; absence is an empty collection.
- Explicitly singular questions return the object or nil; absence is nil.
- Never raise for not-found at a query boundary; let infrastructure exceptions
  (connection down) propagate.
- Internally the root-constant query method wraps a query object or repository
  lookup — invisible to the caller, like all decomposition.


## What Crosses

- In: stable keyword arguments — primitives, uuids, forms, duck-typed objects. The
  receiving context treats every argument as a duck.
- Out: domain objects through command callbacks or query returns.
- Never: another context's internal constants, in either direction. Identities cross
  as uuids.


## Evolving a Contract

Consumers are clients. When a consumer needs different boundary behaviour:

1. The consumer requests the change from the context's owner (even when that is the
   same person — the discipline is the point).
2. The owner grows the boundary: new or changed public method, updated `emits`
   declaration, boundary tests on the owning side.
3. The consumer adopts the grown contract.

Never a consumer-side workaround, never reaching past the interface, never testing
the neighbour's internals.


## Async Crossings

Deferral does not change the protocol:

- An observer may enqueue a job; the job calls a use case as listener
  ([[authoring-use-cases]]; jobs are thin boundaries).
- An event bus is legitimate async *transport*: an event handler is a job that sends
  a public-interface command. The protocol is unchanged, merely deferred.


## Testing a Crossing

- **Caller side**: substitute a spy for the private callable dependency seam and assert
  `#call` received the boundary payload. This narrow composition-seam substitution is not
  permission to stub the caller's behaviour or orchestration.
- When a callback value is merely passed through, use a blind double. A consumer spec does
  not name the neighbour's internal model class merely to verify identity.
- **Callee side**: boundary specs on the owning context's own side, in its own spec
  directory.
- **The crossing itself**: validated at delivery level — the request/acceptance
  specs of the interaction's owner.


## Avoid

- Interrogating a command's return value.
- Wrapper/result objects in either direction — the Result pattern is dead.
- Queries with side effects.
- Raising for absence at a query boundary.
- Calling a neighbour's use cases, query objects, or any internal constant directly —
  the root-constant interface is the only door.
- Spying on the neighbouring root constant from a caller unit spec when a callable
  dependency seam can express the same outgoing command.
- Consumer-side workarounds for a boundary gap — request the boundary change.
