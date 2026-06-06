# Judgment Checklist — Boundaries

These are the questions that inform the architect's call — not an algorithm that
replaces it. An agent proposing a boundary answers them and presents the proposal;
it does not act on an ambiguous answer without sign-off.

## Is this one context or two?
- [ ] Can its one thing be named without "and"?
- [ ] Does every word mean one thing throughout it?
- [ ] Does its code change together (and rarely with outside code)?
- [ ] Can a human+agent pair hold its code + specs in context and work accurately?

## Should this cluster become a slice?
- [ ] Has the cluster met the inputs above as a unit?
- [ ] Is the boundary's contract statable today (what it owns, exposes, consumes)?
- [ ] Pure domain → component; needs Rails abstractions → engine; collection of API
      endpoints → `apis/`. (The three-homes table in authoring-components.)
- [ ] Is the architect's sign-off recorded for the carve?

## Is the crossing clean?
- [ ] Callers send only public-interface messages, listener attached.
- [ ] Identities cross as uuids or duck-typed objects, never internal constants.
- [ ] No invariant is maintained on both sides of the boundary.
- [ ] Any new consumer need is met by a requested boundary change, tested on the
      owning side.

## After any split or merge
- [ ] No caller changed (decomposition is invisible — else the boundary broke).
- [ ] Each README states owns / exposes / consumes / registers.
- [ ] Specs moved with the code they test; each slice's scoped run is green.
