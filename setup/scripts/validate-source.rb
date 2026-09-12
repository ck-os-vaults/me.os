#!/usr/bin/env ruby

require "digest"
require "find"
require "json"
require "pathname"

ROOT = Pathname.new(File.expand_path("../..", __dir__))
MANIFEST_PATH = ROOT.join("setup", "release-manifest.json")
IGNORED_LOCAL_PATTERNS = %w[
  .DS_Store **/.DS_Store .localized **/.localized Thumbs.db **/Thumbs.db desktop.ini **/desktop.ini
  .trash .trash/** tmp tmp/** *.log *.tmp *.swp
].freeze
AGENT_CONFIGURATION_DIRECTORIES = %w[.claude .codex].freeze

errors = []
add = ->(message) { errors << message }

def safe_relative(raw)
  value = raw.to_s.strip
  path = Pathname.new(value)
  clean = path.cleanpath.to_s
  raise ArgumentError, value if value.empty? || path.absolute? || clean == ".." || clean.start_with?("../") || clean != value
  clean
end


def ignored_local_path?(relative)
  IGNORED_LOCAL_PATTERNS.any? { |pattern| File.fnmatch?(pattern, relative, File::FNM_PATHNAME | File::FNM_DOTMATCH) }
end

def public_files(root, add)
  files = {}
  Find.find(root.to_s) do |absolute|
    relative = Pathname.new(absolute).relative_path_from(root).to_s
    if File.symlink?(absolute)
      add.call("unsupported symbolic link: #{relative}")
      next
    end
    if File.directory?(absolute)
      if AGENT_CONFIGURATION_DIRECTORIES.include?(relative)
        add.call("unexpected agent-configuration folder in the public copy: #{relative}; run security intake before use")
        Find.prune
      elsif relative == ".git" || ignored_local_path?(relative)
        Find.prune
      else
        next
      end
    end
    next unless File.file?(absolute)
    next if ignored_local_path?(relative)
    next if relative == "setup/release-manifest.json"
    files[relative] = Digest::SHA256.file(absolute).hexdigest
  end
  files
end

add.call("release manifest is missing") unless MANIFEST_PATH.file? && !MANIFEST_PATH.symlink?

if errors.empty?
  begin
    manifest = JSON.parse(MANIFEST_PATH.read)
    add.call("release manifest does not identify Starter.OS") unless manifest["format"] == 1 && manifest["product"] == "Starter.OS"
    add.call("release manifest has no version") if manifest["version"].to_s.strip.empty?
    add.call("release manifest has an invalid status") unless %w[unreleased released].include?(manifest["status"])
    add.call("unsupported installed record format") unless manifest["installed_record_format"] == 2

    artifacts = manifest.fetch("artifacts")
    artifact_paths = {}
    artifacts.each do |artifact|
      path = safe_relative(artifact.fetch("path"))
      source = safe_relative(artifact.fetch("source"))
      add.call("release attempts to take ownership: #{path}") unless artifact["ownership"] == "owner-owned" && artifact["permitted_editor"] == "owner and approved agents"
      add.call("invalid update strategy: #{path}") unless %w[seed-once-then-preserve offer-if-unmodified].include?(artifact["update"])
      add.call("duplicate installed path in release manifest: #{path}") if artifact_paths[path]
      artifact_paths[path] = true
      source_path = ROOT.join(source)
      if !source_path.file? || source_path.symlink?
        add.call("release file is missing or unsafe: #{source}")
      elsif Digest::SHA256.file(source_path).hexdigest != artifact.fetch("sha256")
        add.call("release file does not match Starter.OS: #{source}")
      end
    end

    recorded = {}
    manifest.fetch("distribution_files").each do |entry|
      path = safe_relative(entry.fetch("path"))
      add.call("duplicate public file in release manifest: #{path}") if recorded.key?(path)
      recorded[path] = entry.fetch("sha256")
    end

    actual = public_files(ROOT, add)
    missing = recorded.keys.sort - actual.keys.sort
    extra = actual.keys.sort - recorded.keys.sort
    changed = (actual.keys & recorded.keys).select { |path| actual[path] != recorded[path] }.sort
    add.call("public files are missing: #{missing.join(', ')}") unless missing.empty?
    add.call("unexpected public files are present: #{extra.join(', ')}") unless extra.empty?
    add.call("public files do not match Starter.OS: #{changed.join(', ')}") unless changed.empty?
  rescue JSON::ParserError => error
    add.call("release manifest is not readable JSON: #{error.message}")
  rescue KeyError => error
    add.call("release manifest is incomplete: #{error.message}")
  rescue ArgumentError => error
    add.call("release manifest contains an unsafe path: #{error.message}")
  end
end

if errors.empty?
  puts "PASS Starter.OS source: this public copy is complete and matches its release manifest"
  exit 0
end

puts "FAIL Starter.OS source: get a fresh copy before setup or update"
errors.each { |message| puts "- #{message}" }
exit 1
