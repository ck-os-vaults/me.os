#!/usr/bin/env ruby

require "digest"
require "find"
require "json"
require "pathname"
require "set"

ROOT = Pathname.new(File.expand_path("../..", __dir__))
OUTPUT = ROOT.join("setup", "release-manifest.json")
RELEASE_VERSION = "3.1.0"
RELEASE_DATE = nil

OWNER_OWNED = Set.new(%w[
  AGENTS.md
  os/me.md
  os/owner-skills.md
  os/recovery.md
  os/integrations.md
  life/knowledge-map.md
  life/now.md
  life/wiki/owner.md
  life/records/decisions.md
]).freeze

HISTORICAL_SOURCES = {
  "2.0.0" => "bb7d3c744348c933b03181a7dffa0b6a8c8701ca",
  "2.1.0" => "dd03a11",
  "3.0.0" => "01f60e03b4ad22b4f9135051df57d73f8a7701f4"
}.freeze
UPDATE_GROUPS = {
  "foundation" => { "description" => "Shared rules, personal extension support, helpers, and validation", "requires" => [] },
  "morning-brief" => { "description" => "Optional Morning Brief recipe; does not enable a schedule", "requires" => [] },
  "news-report" => { "description" => "Optional cited News Report recipe; does not enable a schedule", "requires" => [] },
  "work-wrap" => { "description" => "Optional work closeout recipe", "requires" => [] },
  "reconciliation" => { "description" => "Optional cross-project checkpoint recipe", "requires" => [] },
  "security-watch" => { "description" => "Security review and optional read-only watch recipe", "requires" => [] }
}.freeze
ARTIFACT_GROUPS = {
  "os/skills/daily-brief.md" => "morning-brief", "os/skills/news-report.md" => "news-report",
  "os/skills/eod-wrap.md" => "work-wrap", "os/skills/task-reconciliation.md" => "reconciliation",
  "os/skills/security-sweep.md" => "security-watch"
}.freeze
MANAGED_PATHS = Set.new(%w[
  CLAUDE.md
  life/.gitattributes
  life/.gitignore
  life/AGENTS.md
  life/CLAUDE.md
  life/documents/readme.md
  life/projects/readme.md
  life/readme.md
  life/records/readme.md
  os/.gitattributes
  os/.gitignore
  os/AGENTS.md
  os/CLAUDE.md
  os/knowledge-map.md
  os/license.md
  os/manual.md
  os/retrieval.md
  os/scripts/add-business.rb
  os/scripts/add-project.rb
  os/skill-map.md
  os/skills/browser-use.md
  os/skills/daily-brief.md
  os/skills/decision-log.md
  os/skills/distill.md
  os/skills/drift-recovery.md
  os/skills/eod-wrap.md
  os/skills/git-sync-preflight.md
  os/skills/metadata-audit.md
  os/skills/news-report.md
  os/skills/readme.md
  os/skills/security-intake.md
  os/skills/security-sweep.md
  os/skills/task-reconciliation.md
  os/skills/vault-maintenance.md
  os/templates/daily.md
  os/templates/map.md
  os/templates/note.md
  os/templates/readme.md
  os/templates/root-AGENTS.txt
  os/templates/root-CLAUDE.txt
  os/validate-starter-os.rb
  os/vault-map.md
]).freeze

RENDERERS = {
  "AGENTS.md" => "system-name"
}.freeze

IGNORED_LOCAL_PATTERNS = %w[
  .DS_Store **/.DS_Store .localized **/.localized Thumbs.db **/Thumbs.db desktop.ini **/desktop.ini
  .claude .claude/** .codex .codex/** .trash .trash/** tmp tmp/** *.log *.tmp *.swp
].freeze

TARGET_OVERRIDES = {
  "AGENTS.md" => "os/templates/root-AGENTS.txt",
  "CLAUDE.md" => "os/templates/root-CLAUDE.txt",
  "os/scripts/add-project.rb" => "setup/scripts/add-project.rb",
  "os/scripts/add-business.rb" => "setup/scripts/add-business.rb"
}.freeze

def stop(message)
  warn "Cannot build release manifest: #{message}"
  exit 1
end

def safe_relative(raw)
  path = Pathname.new(raw)
  clean = path.cleanpath.to_s
  stop("unsafe path: #{raw}") if path.absolute? || clean == ".." || clean.start_with?("../") || clean != raw
  clean
end

def sha256(path)
  Digest::SHA256.file(path).hexdigest
end

def ignored_local_path?(relative)
  IGNORED_LOCAL_PATTERNS.any? { |pattern| File.fnmatch?(pattern, relative, File::FNM_PATHNAME | File::FNM_DOTMATCH) }
end

source_targets = {}
Dir.glob(ROOT.join("{os,life}", "**", "*").to_s, File::FNM_DOTMATCH).sort.each do |absolute|
  stop("symbolic links are not allowed in the public release: #{absolute}") if File.symlink?(absolute)
  next unless File.file?(absolute)
  relative = Pathname.new(absolute).relative_path_from(ROOT).to_s
  next if relative == "os/release.json"
  source_targets[relative] = relative
end
TARGET_OVERRIDES.each { |target, source| source_targets[target] = source }

artifacts = source_targets.sort.map do |target, source|
  target = safe_relative(target)
  source = safe_relative(source)
  source_path = ROOT.join(source)
  stop("missing source for #{target}: #{source}") unless source_path.file?

  stop("undeclared artifact ownership: #{target}") unless OWNER_OWNED.include?(target) || MANAGED_PATHS.include?(target)
  ownership = OWNER_OWNED.include?(target) ? "owner-owned" : "managed"
  artifact = {
    "id" => target,
    "path" => target,
    "source" => source,
    "update_group" => ARTIFACT_GROUPS.fetch(target, "foundation"),
    "ownership" => ownership,
    "permitted_editor" => ownership == "managed" ? "Starter.OS update or explicit owner fork" : "owner and approved agents",
    "update" => ownership == "managed" ? "replace-if-unmodified" : "seed-once-then-preserve",
    "deprecation" => "preserve-and-report",
    "sha256" => sha256(source_path)
  }
  artifact["render"] = RENDERERS.fetch(target) if RENDERERS.key?(target)
  artifact
end

duplicates = artifacts.group_by { |artifact| artifact["path"] }.select { |_path, rows| rows.length > 1 }.keys
stop("duplicate target paths: #{duplicates.join(', ')}") unless duplicates.empty?

distribution_files = []
Find.find(ROOT.to_s) do |absolute|
  relative = Pathname.new(absolute).relative_path_from(ROOT).to_s
  stop("symbolic links are not allowed in the public release: #{relative}") if File.symlink?(absolute)
  if File.directory?(absolute)
    if relative == ".git"
      Find.prune
    elsif ignored_local_path?(relative)
      Find.prune
    else
      next
    end
  end
  next unless File.file?(absolute)
  next if ignored_local_path?(relative)
  next if relative == "setup/release-manifest.json"
  distribution_files << {
    "path" => safe_relative(relative),
    "sha256" => sha256(absolute)
  }
end
distribution_files.sort_by! { |entry| entry["path"] }

manifest = {
  "format" => 1,
  "product" => "Starter.OS",
  "version" => RELEASE_VERSION,
  "status" => RELEASE_DATE ? "released" : "unreleased",
  "released" => RELEASE_DATE,
  "supported_updates" => (["unversioned-legacy"] + HISTORICAL_SOURCES.keys + [RELEASE_VERSION]).uniq,
  "historical_sources" => HISTORICAL_SOURCES,
  "supported_partial_updates" => ["3.0.0", RELEASE_VERSION].uniq,
  "update_groups" => UPDATE_GROUPS,
  "licenses" => {
    "code" => "MIT",
    "content" => "CC-BY-4.0"
  },
  "directories" => ["biz"],
  "generated" => [
    {
      "path" => "os/release.json",
      "ownership" => "generated",
      "update" => "regenerate-from-release-manifest"
    }
  ],
  "artifacts" => artifacts,
  "distribution_files" => distribution_files
}

OUTPUT.write("#{JSON.pretty_generate(manifest)}\n")
puts "Built #{OUTPUT.basename}: #{artifacts.length} installed artifacts, #{distribution_files.length} public files"
