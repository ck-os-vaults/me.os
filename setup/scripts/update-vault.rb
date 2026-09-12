#!/usr/bin/env ruby

require "digest"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "time"
require_relative "update-support"
require_relative "update-adaptations"

SOURCE_ROOT = Pathname.new(File.expand_path("../..", __dir__)).realpath
MANIFEST_PATH = SOURCE_ROOT.join("setup", "release-manifest.json")
LEGACY_MANAGED_ROOT_SHA256 = %w[
  f58afce2dc1578b7863a3a272585604926aad72b80ae18f0bb0ab8b52ea11fe1
].freeze

def stop(message)
  warn "Starter.OS update stopped: #{message}"
  exit 1
end

def safe_relative(raw, label = "path")
  value = raw.to_s.strip
  stop("#{label} is blank") if value.empty?
  path = Pathname.new(value)
  clean = path.cleanpath.to_s
  stop("#{label} is unsafe: #{value}") if path.absolute? || clean == "." || clean == ".." || clean.start_with?("../") || clean != value || value.split("/").any? { |part| part.downcase == ".git" }
  clean
end

def sha256(path)
  Digest::SHA256.file(path).hexdigest
end

def artifact_bytes(source, artifact, target_root)
  bytes = File.binread(source)
  return bytes unless artifact["render"]

  stop("unknown artifact renderer: #{artifact['render']}") unless artifact["render"] == "system-name"
  marker = "{{SYSTEM_NAME}}"
  stop("system-name template is missing its marker: #{artifact['source']}") unless bytes.include?(marker)
  bytes.gsub(marker, target_root.basename.to_s)
end

def inside?(path, root)
  path == root || path.to_s.start_with?("#{root}/")
end

def canonical_existing_root(raw, label)
  path = Pathname.new(File.expand_path(raw))
  stop("#{label} itself may not be a symbolic link") if path.symlink?
  stop("#{label} is not a directory") unless path.directory?
  path.realpath
end

def canonical_new_path(path, label)
  stop("#{label} may not be a symbolic link") if path.symlink?
  stop("#{label} already exists: #{path}") if path.exist?

  missing = []
  current = path
  until current.exist?
    stop("#{label} contains a broken symbolic link: #{current}") if current.symlink?
    parent = current.parent
    stop("cannot resolve #{label}") if parent == current
    missing.unshift(current.basename.to_s)
    current = parent
  end

  stop("#{label} crosses a symbolic link: #{current}") if current.symlink?
  stop("#{label} has a non-directory parent: #{current}") unless current.directory?
  missing.reduce(current.realpath) { |resolved, part| resolved.join(part) }
end

def safe_target(root, relative)
  relative = safe_relative(relative)
  UpdateSupport.safe(root, relative)
rescue RuntimeError => error
  stop(error.message)
end


def safe_source(relative)
  current = SOURCE_ROOT
  Pathname.new(relative).each_filename do |part|
    current = current.join(part)
    stop("artifact source crosses a symbolic link: #{relative}") if current.symlink?
  end
  stop("artifact source is missing: #{relative}") unless current.file?
  stop("artifact source escapes the public source: #{relative}") unless inside?(current.realpath, SOURCE_ROOT)
  current
end

def file_state(path)
  return { "exists" => false, "sha256" => nil } unless path.exist?
  stop("expected a regular file but found another type: #{path}") unless path.file? && !path.symlink?
  { "exists" => true, "sha256" => sha256(path) }
end

def load_manifest
  stop("release manifest is missing; run ruby setup/scripts/build-release-manifest.rb") unless MANIFEST_PATH.file?
  checked, status = Open3.capture2e("ruby", SOURCE_ROOT.join("setup/scripts/validate-source.rb").to_s)
  stop("source integrity check failed: #{checked.strip}") unless status.success?
  manifest = JSON.parse(MANIFEST_PATH.read)
  stop("unsupported release manifest") unless manifest["format"] == 1 && manifest["product"] == "Starter.OS"
  manifest.fetch("artifacts").each do |artifact|
    source = safe_relative(artifact.fetch("source"), "artifact source")
    source_path = safe_source(source)
    stop("artifact source changed; rebuild the release manifest: #{source}") unless sha256(source_path) == artifact.fetch("sha256")
  end
  manifest
end

def load_release_record(target)
  path = safe_target(target, "os/release.json")
  return nil unless path.exist?
  stop("installed release record must be a regular file") unless path.file?
  record = JSON.parse(path.read)
  stop("unsupported installed release record") unless [1, 2].include?(record["format"]) && record["product"] == "Starter.OS"
  record
rescue JSON::ParserError => error
  stop("installed release record is invalid JSON: #{error.message}")
end

def recognized_unversioned_starter?(target)
  signatures = {
    "os/AGENTS.md" => /^# Operating rules\s*$/i,
    "os/me.md" => /^type:\s*identity\s*$/i,
    "os/vault-map.md" => /^# vault map\s*$/i,
    "life/AGENTS.md" => /^# Life entry\s*$/i
  }

  root_agents = safe_target(target, "AGENTS.md")
  root_agents.file? && !root_agents.symlink? && signatures.all? do |relative, pattern|
    path = safe_target(target, relative)
    path.file? && !path.symlink? && File.binread(path).force_encoding(Encoding::UTF_8).match?(pattern)
  end
rescue ArgumentError
  false
end

def ensure_update_git_ready(target)
  stop("vault root and biz container must not be Git repositories") if target.join(".git").exist? || target.join("biz/.git").exist?
  %w[os life].each do |name|
    repository = target.join(name)
    top, top_status = Open3.capture2e("git", "-C", repository.to_s, "rev-parse", "--show-toplevel")
    stop("#{name}/ is not protected by its own Git repository; establish and commit working Git history before apply") unless top_status.success?

    begin
      resolved_top = Pathname.new(top.strip).realpath
    rescue Errno::ENOENT
      stop("cannot resolve the #{name}/ Git repository")
    end
    stop("#{name}/ is not an independent Git repository") unless resolved_top == repository.realpath

    head, head_status = Open3.capture2e("git", "-C", repository.to_s, "rev-parse", "--verify", "HEAD")
    stop("#{name}/ has no readable recovery commit; create and verify the approved recovery commit before apply") unless head_status.success? && !head.strip.empty?
    _commit, commit_status = Open3.capture2e("git", "-C", repository.to_s, "cat-file", "-e", "#{head.strip}^{commit}")
    stop("#{name}/ recovery commit cannot be read: #{head.strip}") unless commit_status.success?

    git_dir, git_dir_status = Open3.capture2e("git", "-C", repository.to_s, "rev-parse", "--git-dir")
    stop("cannot inspect the #{name}/ Git operation state") unless git_dir_status.success?
    resolved_git_dir = Pathname.new(git_dir.strip)
    resolved_git_dir = repository.join(resolved_git_dir) unless resolved_git_dir.absolute?
    %w[MERGE_HEAD REBASE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer].each do |marker|
      stop("#{name}/ has a Git operation in progress: #{marker}") if resolved_git_dir.join(marker).exist?
    end

    status_output, status_status = Open3.capture2e("git", "-C", repository.to_s, "status", "--porcelain")
    stop("cannot inspect #{name}/ Git status") unless status_status.success?
    stop("#{name}/ has uncommitted work; create and verify the approved recovery commit before apply") unless status_output.empty?
  end
end

def selected_groups(manifest, requested)
  groups = manifest.fetch("update_groups")
  selected = requested.empty? ? groups.keys : requested.uniq
  stop("unknown update groups: #{(selected - groups.keys).join(', ')}") unless (selected - groups.keys).empty?
  loop do
    expanded = (selected + selected.flat_map { |name| groups.fetch(name).fetch("requires") }).uniq
    break if expanded == selected
    stop("release declares an unknown dependency") unless (expanded - groups.keys).empty?
    selected = expanded
  end
  selected.sort
end

def build_plan(target, manifest, requested = [], adaptations = {}, review_notes = nil)
  installed = load_release_record(target)
  stop("target is not a recognized unversioned Starter.OS; leave it untouched and create a new installation separately") if installed.nil? && !recognized_unversioned_starter?(target)
  installed_version = installed ? installed.fetch("version") : "unversioned-legacy"
  supported_updates = manifest.fetch("supported_updates", [])
  stop("unsupported update path: #{installed_version} -> #{manifest.fetch('version')}") unless supported_updates.include?(installed_version)
  groups = selected_groups(manifest, requested)
  full = groups == manifest.fetch("update_groups").keys.sort
  stop("selective adoption requires a versioned installation; review a full legacy plan first") unless installed || full
  stop("selected adoption is not validated from #{installed_version}; review a full plan or owner-approved adaptation") unless full || manifest.fetch("supported_partial_updates", []).include?(installed_version)
  prior = installed ? installed.fetch("artifacts", {}) : {}
  entries = []
  current_paths = {}

  manifest.fetch("artifacts").each do |artifact|
    path = safe_relative(artifact.fetch("path"), "artifact path")
    current_paths[path] = true
    target_path = safe_target(target, path)
    state = file_state(target_path)
    previous = prior[path]
    ownership = artifact.fetch("ownership")

    action, reason =
      if artifact.fetch("update") == "seed-once-then-preserve"
        if path == "AGENTS.md" && artifact["render"] == "system-name" && state["exists"] && installed.nil? && LEGACY_MANAGED_ROOT_SHA256.include?(state["sha256"])
          ["adopt-owner-entry", "recognized untouched unversioned Starter.OS root entry becomes the owner's named entry"]
        elsif path == "AGENTS.md" && artifact["render"] == "system-name" && state["exists"] && previous && previous["ownership"] == "managed" && state["sha256"] == previous["sha256"]
          ["adopt-owner-entry", "recognized untouched Starter.OS root entry becomes the owner's named entry"]
        elsif state["exists"]
          ["preserve", "seed-only owner content is preserved"]
        elsif previous
          ["conflict", "owner-owned required path is missing; restore the reviewed seed or defer"]
        else
          ["add-seed", "new owner-owned starter file is absent"]
        end
      elsif previous && (previous["ownership"] == "forked" || previous["customized"]) && state["exists"]
        ["forked", "explicit owner fork remains untouched"]
      elsif !state["exists"]
        previous ? ["conflict", "managed file is missing"] : ["add", "new managed file"]
      elsif previous && state["sha256"] == previous["sha256"]
        state["sha256"] == artifact.fetch("sha256") ? ["unchanged", "already matches target release"] : ["update", "managed file matches its installed baseline"]
      else
        previous ? ["modified-preserve", "owner customization is preserved; review relevant upstream differences"] : ["conflict", "legacy installation has no trusted managed baseline"]
      end

    group = artifact.fetch("update_group")
    governance_review = path == "os/AGENTS.md" && (!installed || installed["format"] == 1) && %w[modified-preserve forked conflict].include?(action)
    if governance_review && state["exists"]
      action, reason = ["conflict", "legacy shared rules need exact reviewed governance reconciliation or replacement before the owner-controlled transition"]
    end
    unless groups.include?(group)
      action, reason = ["not-selected", "outside the proposed adoption scope; preserve"]
    end
    if previous && artifact["update"] != "seed-once-then-preserve" && previous["ownership"] == "owner-owned" && (previous["update"].nil? && installed["format"] == 1 || previous["update"] == "seed-once-then-preserve")
      stop("release attempts to take ownership of #{path}; explicit migration is required") if groups.include?(group)
    end
    entries << {
      "path" => path,
      "group" => group,
      "baseline_sha256" => previous && previous["upstream_sha256"],
      "baseline_version" => previous && previous["source_version"],
      "upstream_changed" => previous && (previous.dig("last_reviewed_upstream", "sha256") || previous["upstream_sha256"]) != artifact.fetch("sha256"),
      "source" => artifact.fetch("source"),
      "ownership" => ownership,
      "update" => artifact.fetch("update"),
      "governance_review_required" => governance_review,
      "action" => action,
      "reason" => reason,
      "target_exists" => state["exists"],
      "target_sha256" => state["sha256"],
      "source_sha256" => artifact.fetch("sha256")
    }
  end

  prior.each do |path, previous|
    next if current_paths[path]
    path = safe_relative(path, "deprecated path")
    state = file_state(safe_target(target, path))
    entries << {
      "path" => path,
      "ownership" => previous.fetch("ownership", "unknown"),
      "action" => "deprecated-preserve",
      "reason" => "path is absent from the target release and will not be deleted",
      "target_exists" => state["exists"],
      "target_sha256" => state["sha256"],
      "source_sha256" => nil
    }
  end

  begin
    adapted, review = UpdateAdaptations.review(target, SOURCE_ROOT, adaptations, review_notes, entries)
  rescue RuntimeError => error
    stop(error.message)
  end
  adapted.each do |path, candidate|
    state = file_state(safe_target(target, path))
    entry = entries.find { |row| row["path"] == path }
    unless entry
      entry = { "path" => path, "ownership" => "owner-owned", "target_exists" => state["exists"], "target_sha256" => state["sha256"], "source_sha256" => nil }
      entries << entry
    end
    entry["action"] = state["sha256"] == candidate["sha256"] ? "adapted-unchanged" : "adapt"
    entry["reason"] = "exact owner-reviewed candidate; preservation notes bound to this plan"
    entry["candidate_sha256"] = candidate["sha256"]
  end

  {
    "format" => 1,
    "product" => "Starter.OS",
    "created_at" => Time.now.utc.iso8601,
    "source_root" => SOURCE_ROOT.to_s,
    "source_manifest_sha256" => sha256(MANIFEST_PATH),
    "target_root" => target.to_s,
    "installed_version" => installed_version,
    "target_version" => manifest.fetch("version"),
    "selected_groups" => groups,
    "adoption" => adapted.empty? ? (full ? "full" : "partial") : "adapted",
    "adaptations" => adapted,
    "review_notes" => review,
    "inventory" => UpdateSupport.inventory(target),
    "installed_record_sha256" => target.join("os/release.json").file? ? sha256(safe_target(target, "os/release.json")) : nil,
    "entries" => entries.sort_by { |entry| entry["path"] }
  }
end

def print_summary(plan)
  counts = plan.fetch("entries").group_by { |entry| entry.fetch("action") }.transform_values(&:length)
  puts "Starter.OS update plan: #{plan.fetch('installed_version')} -> #{plan.fetch('target_version')}"
  counts.sort.each { |action, count| puts "- #{action}: #{count}" }
  conflicts = plan.fetch("entries").select { |entry| entry["action"] == "conflict" }
  conflicts.each { |entry| puts "  conflict #{entry.fetch('path')}: #{entry.fetch('reason')}" }
  puts "Scope: #{plan.fetch('adoption')} — #{plan.fetch('selected_groups').join(', ')}"
  plan.fetch("entries").select { |entry| %w[forked modified-preserve].include?(entry["action"]) && entry["upstream_changed"] }.each do |entry|
    puts "  upstream improvement available for owner fork: #{entry.fetch('path')} (kept unless explicitly reconciled)"
  end
end

allow_unreleased = !!ARGV.delete("--allow-unreleased")
command = ARGV.shift
manifest = load_manifest
if command == "apply" && manifest["status"] != "released" && !allow_unreleased
  stop("this source is an unreleased candidate; use an approved released source or explicitly approve --allow-unreleased")
end

case command
when "plan"
  target_raw = ARGV.shift
  output_raw = ARGV.shift
  stop("usage: update-vault.rb plan TARGET PLAN.json [--only GROUP]") if target_raw.to_s.empty? || output_raw.to_s.empty?
  requested = []
  adaptations = {}
  review_notes = nil
  until ARGV.empty?
    case ARGV.shift
    when "--only"
      requested << ARGV.shift.to_s
    when "--adapt"
      path, file = ARGV.shift.to_s.split("=", 2)
      stop("--adapt requires PATH=EXTERNAL_FILE") if path.to_s.empty? || file.to_s.empty?
      stop("duplicate adaptation") if adaptations.key?(path)
      adaptations[path] = file
    when "--review"
      stop("duplicate review notes") if review_notes
      review_notes = ARGV.shift
      stop("--review requires an external notes file") if review_notes.to_s.empty?
    else
      stop("plan accepts --only GROUP, --adapt PATH=EXTERNAL_FILE, and --review NOTES.md")
    end
  end

  target_path = Pathname.new(File.expand_path(target_raw))
  output = canonical_new_path(Pathname.new(File.expand_path(output_raw)), "plan output")
  stop("target is not a Starter.OS folder") unless target_path.directory? && target_path.join("os").directory? && target_path.join("life").directory?
  target = canonical_existing_root(target_raw, "target")
  stop("target must be outside the public source") if inside?(target, SOURCE_ROOT) || inside?(SOURCE_ROOT, target)
  stop("plan output must be outside the installed vault") if inside?(output, target)

  stop("plan output must be outside the public source") if inside?(output, SOURCE_ROOT)
  plan = build_plan(target, manifest, requested, adaptations, review_notes)
  output.dirname.mkpath
  output.write("#{JSON.pretty_generate(plan)}\n")
  print_summary(plan)
  puts "Plan written to #{output}"

when "apply"
  target_raw = ARGV.shift
  plan_raw = ARGV.shift
  stop("usage: update-vault.rb apply TARGET PLAN.json --root-backup DIR [--keep PATH] [--replace PATH] [--fork SOURCE=DESTINATION]") if target_raw.to_s.empty? || plan_raw.to_s.empty?

  keep = []
  replace = []
  forks = {}
  root_backup_raw = nil
  until ARGV.empty?
    option = ARGV.shift
    case option
    when "--keep"
      keep << safe_relative(ARGV.shift, "--keep path")
    when "--replace"
      replace << safe_relative(ARGV.shift, "--replace path")
    when "--fork"
      raw = ARGV.shift.to_s
      source, destination = raw.split("=", 2)
      source = safe_relative(source, "--fork source")
      destination = safe_relative(destination, "--fork destination")
      stop("duplicate --fork source: #{source}") if forks.key?(source)
      forks[source] = destination
    when "--root-backup"
      stop("duplicate --root-backup") if root_backup_raw
      root_backup_raw = ARGV.shift.to_s.strip
      stop("--root-backup directory is blank") if root_backup_raw.empty?
    else
      stop("unknown option: #{option}")
    end
  end

  target_path = Pathname.new(File.expand_path(target_raw))
  plan_path = Pathname.new(File.expand_path(plan_raw))
  stop("target is not a Starter.OS folder") unless target_path.directory? && target_path.join("os").directory? && target_path.join("life").directory?
  target = canonical_existing_root(target_raw, "target")
  stop("target must be outside the public source") if inside?(target, SOURCE_ROOT) || inside?(SOURCE_ROOT, target)
  stop("plan file may not be a symbolic link") if plan_path.symlink?
  stop("plan file is missing") unless plan_path.file?
  plan = JSON.parse(plan_path.read)
  stop("unsupported update plan") unless plan["format"] == 1 && plan["product"] == "Starter.OS"
  stop("plan belongs to another target: #{plan['target_root']}") unless plan["target_root"] == target.to_s
  stop("plan belongs to another source checkout") unless plan["source_root"] == SOURCE_ROOT.to_s
  stop("public release manifest changed after planning") unless plan["source_manifest_sha256"] == sha256(MANIFEST_PATH)
  stop("plan targets a different release") unless plan["target_version"] == manifest["version"]

  expected_plan = build_plan(target, manifest, plan.fetch("selected_groups"), plan.fetch("adaptations").transform_values { |record| record.fetch("input") }, plan["review_notes"] && plan["review_notes"].fetch("input"))
  comparable_fields = %w[source_root source_manifest_sha256 target_root installed_version target_version entries selected_groups adoption adaptations review_notes inventory installed_record_sha256]
  unless comparable_fields.all? { |field| plan[field] == expected_plan[field] }
    stop("plan contents do not match the current source and target; create and review a new plan")
  end

  ensure_update_git_ready(target)

  entries = plan.fetch("entries")
  by_path = entries.to_h { |entry| [entry.fetch("path"), entry] }
  entries.each do |entry|
    state = file_state(safe_target(target, entry.fetch("path")))
    unless state["exists"] == entry["target_exists"] && state["sha256"] == entry["target_sha256"]
      stop("target changed after planning: #{entry.fetch('path')}")
    end
  end

  choices = keep + replace + forks.keys
  stop("a path has more than one conflict choice") unless choices.uniq.length == choices.length
  choices.each do |path|
    stop("choice does not name a planned conflict or customization: #{path}") unless by_path[path] && %w[conflict forked modified-preserve].include?(by_path[path]["action"])
  end
  choices.each do |path|
    next if by_path.fetch(path)["target_exists"]
    stop("a missing required path can only use --replace: #{path}") unless replace.include?(path)
  end
  stop("legacy shared rules require an exact reviewed --adapt candidate or --replace, not --keep") if keep.any? { |path| by_path.fetch(path)["governance_review_required"] }
  stop("two forks may not use the same destination") unless forks.values.map(&:downcase).uniq.length == forks.values.length

  conflicts = entries.select { |entry| entry["action"] == "conflict" }.map { |entry| entry["path"] }
  unresolved = conflicts - choices
  stop("conflicts need an approved --keep, --replace, or --fork choice: #{unresolved.join(', ')}") unless unresolved.empty?

  prepared_forks = forks.map do |source, destination|
    stop("fork destination must be inside the protected os/ or life/ repository") unless destination.start_with?("os/", "life/")
    stop("fork destination conflicts with generated release metadata") if manifest.fetch("generated").any? { |artifact| artifact.fetch("path").downcase == destination.downcase }
    destination_path = safe_target(target, destination)
    stop("fork destination already exists: #{destination}") if destination_path.exist?
    stop("fork destination conflicts with a managed release path: #{destination}") if by_path.key?(destination)
    source_path = safe_target(target, source)
    stop("fork source is missing: #{source}") unless source_path.file?
    [source_path, destination_path]
  end

  previous_record = load_release_record(target)
  previous_artifacts = previous_record ? previous_record.fetch("artifacts", {}) : {}
  same_adoption = previous_record && previous_record.dig("adoption", "manifest_sha256") == sha256(MANIFEST_PATH) && previous_record.dig("adoption", "groups") == plan["selected_groups"]
  if choices.empty? && previous_record && previous_record["format"] == 2 && (plan["installed_version"] == manifest["version"] || same_adoption) && entries.all? { |entry| %w[unchanged preserve forked modified-preserve deprecated-preserve not-selected adapted-unchanged].include?(entry["action"]) }
    puts "No changes: the installed release is current; owner files and forks remain untouched."
    exit 0
  end

  writes = {}
  prepared_forks.each do |source_path, destination_path|
    writes[destination_path.relative_path_from(target).to_s] = { "bytes" => source_path.binread, "mode" => source_path.stat.mode & 0o777 }
  end
  manifest_by_path = manifest.fetch("artifacts").to_h { |artifact| [artifact.fetch("path"), artifact] }
  entries.each do |entry|
    path = entry.fetch("path")
    install = %w[add add-seed update adopt-owner-entry].include?(entry.fetch("action")) || replace.include?(path) || forks.key?(path)
    next unless install
    artifact = manifest_by_path.fetch(path)
    source = safe_source(safe_relative(artifact.fetch("source"), "artifact source"))
    writes[path] = { "bytes" => artifact_bytes(source, artifact, target), "mode" => source.stat.mode & 0o777 }
  end
  plan.fetch("adaptations").each do |path, record|
    next if by_path.fetch(path)["action"] == "adapted-unchanged"
    writes[path] = { "bytes" => UpdateAdaptations.bytes(record), "mode" => record.fetch("mode") }
  end

  # Record routing for a copied manual in owner context as part of this exact transaction.
  if forks.key?("os/manual.md")
    owner_context = safe_target(target, "os/me.md")
    destination = forks.fetch("os/manual.md")
    if plan.fetch("adaptations").key?("os/me.md")
      bytes = UpdateAdaptations.bytes(plan.fetch("adaptations").fetch("os/me.md"))
      stop("manual-fork routing overlaps the exact owner-context adaptation; include the approved route in a new reviewed candidate") unless bytes.include?(destination)
    else
      bytes = owner_context.binread
      bytes += "\nManual fork: #{destination}. Created through the approved update plan.\n" unless bytes.include?(destination)
    end
    writes["os/me.md"] = { "bytes" => bytes }
  end

  # Normalize governance even for declined groups, retaining their source/fork
  # evidence. A legacy ownership label must not remain an edit restriction.
  release_artifacts = previous_artifacts.to_h do |path, previous|
    value = previous.dup
    value["legacy_ownership"] ||= value["ownership"] unless value["ownership"] == "owner-owned"
    value["customized"] = true if value["ownership"] == "forked"
    value["ownership"] = "owner-owned"
    value["update"] ||= previous["ownership"] == "owner-owned" ? "seed-once-then-preserve" : "offer-if-unmodified"
    [path, value]
  end
  manifest.fetch("artifacts").each do |artifact|
    path = artifact.fetch("path")
    next if by_path.fetch(path)["action"] == "not-selected"
    previous = previous_artifacts[path]
    forked = keep.include?(path) || (%w[forked modified-preserve adapt adapted-unchanged].include?(by_path.fetch(path)["action"]) && !replace.include?(path) && !forks.key?(path))
    digest = writes.key?(path) ? Digest::SHA256.hexdigest(writes[path].fetch("bytes")) : file_state(safe_target(target, path))["sha256"]
    record = (previous || {}).merge(
      "ownership" => "owner-owned",
      "update" => artifact.fetch("update"),
      "customized" => forked,
      "sha256" => forked && previous ? previous["sha256"] : digest,
      "upstream_sha256" => forked && previous ? previous["upstream_sha256"] : artifact.fetch("sha256"),
      "source_version" => forked && previous ? previous["source_version"] : manifest.fetch("version")
    )
    if forked
      record["owner_sha256_at_review"] = digest
      record["legacy_ownership"] = previous["legacy_ownership"] || previous["ownership"] if previous
      record["fork_base"] = previous && previous["fork_base"] || {
        "sha256" => previous && previous["upstream_sha256"],
        "version" => previous && previous["source_version"],
        "manifest_sha256" => previous_record && previous_record["manifest_sha256"]
      }
      record["available_upstream"] = { "version" => manifest.fetch("version"), "sha256" => artifact.fetch("sha256") }
      record["last_reviewed_upstream"] = keep.include?(path) ? record["available_upstream"] : previous && previous["last_reviewed_upstream"]
    else
      record.delete("available_upstream")
      record.delete("last_reviewed_upstream")
    end
    release_artifacts[path] = record
  end
  plan.fetch("adaptations").each do |path, candidate|
    next if manifest_by_path.key?(path)
    release_artifacts[path] = (previous_artifacts[path] || {}).merge("ownership" => "owner-owned", "update" => "seed-once-then-preserve", "customized" => true, "owner_sha256_at_review" => candidate.fetch("sha256"))
  end
  retained_forks = previous_record ? previous_record.fetch("forks", []) : []
  retained_forks = retained_forks.reject { |record| forks.key?(record["source"]) }
  new_forks = forks.map do |source, destination|
    { "source" => source, "destination" => destination,
      "sha256" => Digest::SHA256.hexdigest(writes.fetch(destination).fetch("bytes")),
      "baseline" => previous_artifacts[source], "upstream_version_at_copy" => manifest.fetch("version") }
  end
  full = plan.fetch("adoption") == "full"
  now = Time.now.utc.iso8601
  release_record = (previous_record || {}).merge(
    "format" => 2, "product" => "Starter.OS",
    "ownership_model" => "owner-controlled",
    "version" => full ? manifest.fetch("version") : plan.fetch("installed_version"),
    "installed_at" => previous_record ? previous_record["installed_at"] : nil,
    "updated_at" => now,
    "installed_source" => previous_record && previous_record["installed_source"] || { "version" => plan.fetch("installed_version"), "manifest_sha256" => previous_record && previous_record["manifest_sha256"] },
    "manifest_sha256" => full ? sha256(MANIFEST_PATH) : previous_record && previous_record["manifest_sha256"],
    "artifacts" => release_artifacts, "forks" => retained_forks + new_forks,
    "adoption" => { "kind" => plan.fetch("adoption"), "offered_version" => manifest.fetch("version"), "groups" => plan.fetch("selected_groups"), "manifest_sha256" => sha256(MANIFEST_PATH), "adapted_paths" => plan.fetch("adaptations").keys, "review_sha256" => plan["review_notes"] && plan["review_notes"]["sha256"] },
    "deprecated_preserved" => entries.select { |entry| entry["action"] == "deprecated-preserve" && entry["target_exists"] }.map { |entry| entry["path"] }
  )
  safe_target(target, "os/release.json")
  writes["os/release.json"] = { "bytes" => "#{JSON.pretty_generate(release_record)}\n" }
  writes.delete_if { |path, payload| safe_target(target, path).file? && safe_target(target, path).binread == payload.fetch("bytes") }

  validator_record = release_artifacts["os/validate-starter-os.rb"]
  if previous_record && previous_record["format"] == 1 && validator_record && validator_record["customized"] && !plan.fetch("adaptations").key?("os/validate-starter-os.rb")
    stop("new record requires a compatible validator; review an exact validator adaptation or replacement")
  end

  stop("--root-backup DIR is required so non-repository root entry files can be restored") unless root_backup_raw
  root_backup = canonical_new_path(Pathname.new(File.expand_path(root_backup_raw)), "root backup")
  stop("root backup must be outside the installed vault") if inside?(root_backup, target) || inside?(target, root_backup)
  stop("root backup must be outside the public source") if inside?(root_backup, SOURCE_ROOT) || inside?(SOURCE_ROOT, root_backup)
  FileUtils.mkdir_p(root_backup, mode: 0o700)
  stop("root backup changed while it was being created") unless root_backup.realpath == root_backup
  begin
    if plan["review_notes"]
      UpdateSupport.atomic_write(root_backup, "preservation-notes.md", UpdateAdaptations.bytes(plan.fetch("review_notes")), mode: 0o600)
    end
    stop("target changed after review") unless UpdateSupport.inventory(target) == plan.fetch("inventory")
    receipt = UpdateSupport.prepare(target, root_backup, writes, plan)
    UpdateSupport.apply(target, root_backup, receipt)
  rescue StandardError => error
    stop("#{error.message}; preserve the transaction and review restore-vault.rb plan TARGET #{root_backup}")
  end

  applied_plan = build_plan(target, manifest, plan.fetch("selected_groups"))
  remaining_conflicts = applied_plan.fetch("entries").select { |entry| entry["action"] == "conflict" }
  stop("post-apply state still has conflicts; restore from #{root_backup}") unless remaining_conflicts.empty?
  print_summary(applied_plan)
  puts full ? "Applied Starter.OS #{manifest.fetch('version')} with owner content preserved" : "Applied #{plan.fetch('adoption')} #{manifest.fetch('version')} improvements; base release remains #{plan.fetch('installed_version')}"
  puts "Recovery transaction: #{root_backup}"
  puts "Next: validate the installed system, review the diff, and verify approved hosted protection separately"

else
  stop("usage: update-vault.rb plan TARGET PLAN.json | apply TARGET PLAN.json --root-backup DIR [choices]")
end
