# common_agent_skills/derisk_layers/testing-graphql/references/checklist.md


# Review Checklist — GraphQL Acceptance Specs


## Scope

- [ ] Acceptance spec only — no unit specs exist for the mutation/resolver/types involved.
- [ ] Behaviour edge cases covered in the user story's own spec, not duplicated here.


## Structure
- [ ] `require 'rails_helper'` and `type: %i[request acceptance]` (both types — needed for the
      response helpers).
- [ ] `query`/`mutation` document in a `let`; `variables` as a JSON string; `params` let.
- [ ] Response parts pulled into `let`s via `dig`, with `errors` defaulting to `[]`.
- [ ] `post '/graphql', params: params.to_json, headers: headers` in a single `execute`.

## Auth
- [ ] `include_context 'with api authentication'` and `graphql_authenticated_headers` for
      authenticated cases.
- [ ] `it_behaves_like 'requires authentication'` on protected operations.

## Mutations
- [ ] Field-by-field assertions on the payload.
- [ ] `errors` empty on success; message AND path asserted on failure.
- [ ] Persistence asserted with `change(Model, :count)` block matchers (and `not_to change`).

## Queries
- [ ] Fixtures created with `let!`.
- [ ] Whole-shape `expect(response_data).to eq(expected_response)`.
- [ ] Empty-result case covered.
- [ ] Scoping case covered (other users'/tenants' records excluded).

## Avoid
- [ ] No `post` inside an `it` except block matchers.
- [ ] One expectation per `it` (a single whole-shape `eq` counts as one).
