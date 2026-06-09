# Authoring Checklist — API Endpoints

## Generate, don't hand-create
- [ ] Ran `bin/rails generate layers:api_endpoint <resource>/<action> --engine <name>`.
- [ ] It is a command (create/update/destroy) — a read is a query object + serializer,
      not this scaffold.
- [ ] Ran `bundle install` if the engine was new; confirmed the injected route and the
      use-case registration in `config/initializers/<engine>.rb`.

## Container (use case + form)
- [ ] Use case takes the inputs and builds its `Forms::` peer; persistence in a
      transaction ([[authoring-use-cases]]).
- [ ] Form declares accessors, validations, builders, and the `report_full_errors_for`
      whitelist ([[authoring-layers-forms]]).

## Engine (story + controller + serializer)
- [ ] Story forwards the inputs to the use case via the registry; names no container
      constant.
- [ ] Controller action forwards `current_authorization` + permitted params to the story;
      callbacks render success and failure; no form built, no use case named.
- [ ] Serializer exposes the right attributes.

## Verify
- [ ] Request spec ([[testing-rails-requests]]) covers success, validation failure, and
      the route's security posture.
- [ ] Routing spec ([[testing-routing]]) covers the action's verb + path.
- [ ] `Layers/SliceReferencesContainerLayer` passes (no `UseCases::`/`Queries::` named in
      the engine).
