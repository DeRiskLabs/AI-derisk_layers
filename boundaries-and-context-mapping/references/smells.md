# Boundary Smells — and Their Responses

Two catalogues: contexts grown too big, and boundaries carved too fine. Every
response preserves the public interface — decomposition is invisible or it is wrong.


## Overgrown context

| Smell | What it looks like | Response |
| --- | --- | --- |
| Interface bloat | The root constant (or module interface) carries so many public methods nobody can say what the context is for | First group methods into collections (modules mixed into the root constant); if grouping reads like *separate concepts*, split the context |
| "And" in the description | "Billing handles invoicing **and** dunning **and** payout reconciliation" | Each "and" marks a candidate sub-context: decompose internally first; promote to a sibling context only when an outside caller genuinely needs it directly |
| Registry sprawl | A component's repository registry spans unrelated model clusters | The context is reaching across business concepts — split along the cluster line |
| Vocabulary drift | The same word means different things in different corners of one context | Two languages = two contexts; the boundary goes where the meaning shifts |
| Too big to hold | A human+agent pair cannot hold the context's code + specs in context and work accurately | Split it; the context-window test is a hard sizing limit, not a preference |
| Internal chains | Use cases calling long chains of unrelated use cases inside one context | The chain links different concepts — find the seam and split there |


## Boundary carved too fine

| Smell | What it looks like | Response |
| --- | --- | --- |
| Chatty crossing | Every operation in context A round-trips to context B | A and B share one business concept — merge them, or move the behaviour to whichever owns it |
| Circular requests | A consumes B's interface and B consumes A's | No clean owner exists at this carving; re-carve so dependency flows one way, or merge |
| Duplicated rules | The same validation or invariant maintained on both sides of a boundary | The invariant has exactly one owner; the other side requests it through the boundary |
| Anemic context | A context with one trivial use case and no growth path | Fold it into its consumer; a boundary must earn its contract-maintenance cost |
| Shared internals | Two "separate" contexts reaching into a common pile of helpers | The pile is the real context; name it and give it an interface — or admit the two are one |


## A worked carving

A fat main app accumulates `app/lib/use_cases/registration/…` — sign-up, invites,
role assignment, email verification, eighteen use cases. Judgment inputs: one
nameable concept ("everything to do with user registration"), its own vocabulary
(invite, grant, verification), changes together, no Rails abstractions in the rules
themselves.

Carve: `components/registration/` exposing a handful of root-constant methods
(`Registration.sign_up`, `Registration.accept_invite`, …). Internally it may organize
as interface management + authorization + role granting — callers never learn this.
The delivery endpoints stay in `apis/`, now thin: build form, send one message,
listen. The eighteen use cases become internal collaborators; only the boundary
methods are public API.
