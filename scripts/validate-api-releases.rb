#!/usr/bin/env ruby
# Cross-file and Git checks only; native rules enforce manifest value policy.
require 'yaml'
require 'date'
require 'open3'

def load_yaml(path)
  # Safe loading retains local !file scalars as strings; no expansion or lookup.
  YAML.safe_load_file(path, aliases: false, permitted_classes: [Date, Time])
end

def check(condition, message)
  abort(message) unless condition
end

def git!(*args)
  output, status = Open3.capture2('git', *args)
  check(status.success?, "git #{args.join(' ')} failed")
  output
end

development_version = load_yaml('openapi.yaml').fetch('info').fetch('version')
dev_apis = load_yaml('konnect/dev.yaml').fetch('apis')
dev_versions = load_yaml('konnect/dev-versions.yaml').fetch('apis')
check(dev_apis.length == 1 && dev_versions.length == 1,
      'development must declare one API in each invocation manifest')
check(dev_apis.first.fetch('version') == '../openapi.yaml#info.version' &&
      dev_versions.first.fetch('versions').length == 1 &&
      dev_versions.first.fetch('versions').first.fetch('version') == '../openapi.yaml#info.version' &&
      dev_versions.first.fetch('versions').first.fetch('spec') == '../openapi.yaml',
      'development manifests must select and add the version from openapi.yaml')

prod_apis = load_yaml('konnect/prod.yaml').fetch('apis')
check(prod_apis.length == 1, 'production must select exactly one API version')
production = prod_apis.first
production_version = production.fetch('version')
check(production_version.is_a?(String) && production_version.match?(/\A\d+\.\d+\.\d+\z/),
      'production version must be a stable semantic version')
check(File.file?("openapi/versions/#{production_version}.yaml"),
      "current production specification #{production_version} does not exist")

releases = Dir.glob('openapi/versions/*.yaml')
check(!releases.empty?, 'openapi/versions must contain a stable release')
entries = production.fetch('versions')
releases.each do |path|
  version = File.basename(path, '.yaml')
  check(version.match?(/\A\d+\.\d+\.\d+\z/), "#{path} needs a stable semantic-version filename")
  check(load_yaml(path).fetch('info').fetch('version') == version,
        "#{path} info.version must match its filename")
  check(entries.any? { |entry| entry['version'] == "../#{path}#info.version" && entry['spec'] == "../#{path}" },
        "konnect/prod.yaml must retain the paired version/spec for #{path}")
end
entries.each do |entry|
  spec = entry.fetch('spec')
  check(spec.is_a?(String) && spec.match?(/\A\.\.\/openapi\/versions\/\d+\.\d+\.\d+\.yaml\z/),
        'production specs must be stable files under openapi/versions')
  check(File.file?(spec.delete_prefix('../')), "missing production spec #{spec}")
end

base = ARGV.first.to_s
unless base.empty?
  git!('cat-file', '-e', "#{base}^{commit}")
  changed = git!('diff', '--name-only', '--diff-filter=MDRT', base, '--', 'openapi/versions')
  check(changed.empty?, "released OpenAPI specifications are immutable:\n#{changed}")
  _output, status = Open3.capture2('git', 'diff', '--quiet', base, '--', 'openapi.yaml')
  check([0, 1].include?(status.exitstatus), 'cannot compare development contract with base')
  unless status.success?
    previous = YAML.safe_load(git!('show', "#{base}:openapi.yaml"), aliases: false, permitted_classes: [Date, Time]).fetch('info').fetch('version')
    check(previous != development_version, "openapi.yaml changed without advancing info.version from #{previous}")
  end
end
