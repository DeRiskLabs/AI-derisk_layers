# Crossing Checklist — Cross-Context Communication

## Classify
- [ ] State change that can succeed or fail → command (use case + listener).
- [ ] Side-effect-free ask → query (plain return).
- [ ] Nothing in between: no query touches state; no command's return value is used.

## Command — caller
- [ ] Message sent through a role-named callable dependency that resolves to the
      root-constant public method, listener (or delegate) attached.
- [ ] The callable is resolved behind a private method so a future boot-filled registry
      does not change the operation.
- [ ] Callbacks implemented exactly per the contract's payload keys.
- [ ] Failure handling extracts errors from the failure payload (`.errors` object or
      errors collection).
- [ ] Console operators included: change is effected via public commands, never raw
      model writes.

## Command — callee
- [ ] Root-constant method is a thin pass-through to a use case.
- [ ] `emits success: [...], failure: [...]` declares the payload contract.
- [ ] Failure payloads carry the means to render errors.

## Query
- [ ] Zero side effects (no create-if-missing, no touch, no DB memoization).
- [ ] Collection question → enumerable, possibly empty, never nil.
- [ ] Singular question → object or nil.
- [ ] No raising for absence; no wrapper objects.

## The boundary itself
- [ ] Identities cross as uuids; arguments are primitives/forms/ducks.
- [ ] No internal constants cross in either direction.
- [ ] A consumer gap becomes a boundary-change request to the owner — never a
      consumer-side workaround.
- [ ] Async crossings (observer → job, event handler → job) end in a public-interface
      command — deferral does not change the protocol.

## Verify
- [ ] Caller specs substitute the private callable seam and assert its outgoing `#call`.
- [ ] Caller specs use blind doubles for opaque callback values and do not name the
      neighbour's internal model classes.
- [ ] Callee boundary specs live on the owning side, in its spec directory.
- [ ] The crossing is covered by the interaction owner's delivery-level specs.
