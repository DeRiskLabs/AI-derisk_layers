# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = 'ai-derisk_layers'
  spec.version     = '0.2.0'
  spec.authors     = ['DeriskLabs']
  spec.email       = ['engineering@derisklabs.com']

  spec.summary     = 'Skills for AI coding agents using the layers gem in a Rails app.'
  spec.description = 'The derisk_layers skill collection: SKILL.md documents covering layered ' \
                     'architecture placement and the authoring and testing of use cases, user ' \
                     'stories, query objects, and GraphQL endpoints built on the layers gem. ' \
                     'Depends on the more general derisk collections it references. ' \
                     'Data-only gem; nothing to require.'
  spec.homepage    = 'https://github.com/DeriskLabs/AI-derisk_layers'
  spec.license     = 'MIT'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'rubygems_mfa_required' => 'true',
  }

  spec.files = Dir['INDEX.md', 'LICENSE.txt', '*/**/*'].select { |f| File.file?(f) }

  spec.require_paths = []

  spec.add_dependency 'ai-derisk_rails', '~> 0.1'
end
