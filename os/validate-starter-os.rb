#!/usr/bin/env ruby

require "digest"
require "json"
require "open3"
require "pathname"

ROOT = Pathname.new(File.expand_path("..", __dir__))
IGNORED_COMPUTER_FILES = %w[.DS_Store .localized Thumbs.db desktop.ini].freeze
foundation_mode = ARGV.delete("--foundation")
abort "usage: validate-starter-os.rb [--foundation]" unless ARGV.empty?
Dir.chdir(ROOT)

errors = []
add = ->(message) { errors << message }
notices = []
notice = ->(message) { notices << message }

def symlink_component?(relative)
  current = Pathname.new(".")
  Pathname.new(relative).each_filename do |part|
    current = current.join(part)
    return true if current.symlink?
  end
  false
end

def check_local_git(add, repository, label)
  top, top_status = Open3.capture2e("git", "-C", repository, "rev-parse", "--show-toplevel")
  unless top_status.success?
    add.call("#{label} is not protected by its own Git repository")
    return
  end

  begin
    add.call("#{label} is not an independent Git repository") unless Pathname.new(top.strip).realpath == Pathname.new(repository).realpath
  rescue Errno::ENOENT
    add.call("#{label} Git root cannot be resolved")
    return
  end

  head, head_status = Open3.capture2e("git", "-C", repository, "rev-parse", "--verify", "HEAD")
  unless head_status.success? && !head.strip.empty?
    add.call("#{label} has no readable recovery commit")
    return
  end

  _commit, commit_status = Open3.capture2e("git", "-C", repository, "cat-file", "-e", "#{head.strip}^{commit}")
  add.call("#{label} recovery commit cannot be read: #{head.strip}") unless commit_status.success?
rescue Errno::ENOENT
  add.call("#{label} Git executable is unavailable; readable recovery cannot be verified")
end

required = %w[
  AGENTS.md
  CLAUDE.md
  os/AGENTS.md
  os/CLAUDE.md
  os/manual.md
  os/license.md
  os/release.json
  os/me.md
  os/owner-skills.md
  os/vault-map.md
  os/knowledge-map.md
  os/retrieval.md
  os/recovery.md
  os/integrations.md
  os/skill-map.md
  os/skills/drift-recovery.md
  os/skills/security-intake.md
  os/skills/security-sweep.md
  os/skills/daily-brief.md
  os/skills/news-report.md
  os/skills/task-reconciliation.md
  os/validate-starter-os.rb
  os/scripts/add-project.rb
  os/scripts/add-business.rb
  life/AGENTS.md
  life/CLAUDE.md
  life/now.md
  life/knowledge-map.md
  life/documents/readme.md
  life/projects/readme.md
  life/wiki/owner.md
  life/records/readme.md
  life/records/decisions.md
  biz
]
required.each do |path|
  add.call("missing #{path}") unless File.exist?(path)
  add.call("required path crosses a symbolic link: #{path}") if symlink_component?(path)
end

add.call("distribution setup folder remains in private system") if File.exist?("setup")
%w[life/00_inbox life/areas life/archive life/records/sessions biz/business-model].each do |path|
  notice.call("preserved owner content at legacy path: #{path}; review only if useful") if File.exist?(path)
end
history_check = lambda do |repository, label|
  if foundation_mode && !File.exist?(File.join(repository, ".git"))
    begin
      top, status = Open3.capture2e("git", "-C", repository, "rev-parse", "--show-toplevel")
    rescue Errno::ENOENT
      ancestor = Pathname.new(repository).realpath
      inherited_metadata = false
      loop do
        inherited_metadata ||= ancestor.join(".git").exist? || ancestor.join(".git").symlink?
        break if ancestor.parent == ancestor
        ancestor = ancestor.parent
      end
      if inherited_metadata
        add.call("#{label} has ancestor Git metadata but Git is unavailable; inspect topology before proceeding")
      else
        notice.call("#{label} Git is unavailable; owner-deferred protection, not a verified recovery point")
      end
      next
    end
    if status.success?
      add.call("#{label} inherits another repository; inspect privacy and topology")
    else
      notice.call("#{label} has no Git history; owner-deferred protection, not a verified recovery point")
    end
  else
    check_local_git(add, repository, label)
  end
end

add.call("vault root must not be a Git repository") if File.exist?(".git")
add.call("biz container must not be a Git repository") if File.exist?("biz/.git")
history_check.call("os", "os/") if File.directory?("os")
history_check.call("life", "life/") if File.directory?("life")

if File.file?("AGENTS.md")
  root_agents = File.read("AGENTS.md")
  root_record = begin
    JSON.parse(File.read("os/release.json")).dig("artifacts", "AGENTS.md") if File.file?("os/release.json")
  rescue JSON::ParserError
    nil
  end
  rendered_seed = if File.file?("os/templates/root-AGENTS.txt")
    File.read("os/templates/root-AGENTS.txt").gsub("{{SYSTEM_NAME}}", ROOT.basename.to_s)
  end
  customized_owner_root = root_record && root_record["ownership"] == "owner-owned" && rendered_seed && root_agents != rendered_seed
  add.call("root AGENTS.md still identifies the public Starter.OS source") if root_agents.match?(/^# Starter\.OS entry$/) || root_agents.include?("setup/release-manifest.json")

  root_checks = {
    "does not route to os/AGENTS.md" => root_agents.include?("os/AGENTS.md"),
    "does not route to os/me.md" => root_agents.include?("os/me.md"),
    "does not route project and business work to the nearest AGENTS.md" => root_agents.match?(/nearest.*AGENTS\.md/im) && root_agents.match?(/life.*biz/im),
    "does not retain the upstream release route" => root_agents.include?("os/release.json")
  }
  root_checks.each do |message, passes|
    next if passes
    if customized_owner_root
      notice.call("preserved owner root AGENTS.md #{message}; reconcile only with the owner's approval")
    else
      add.call("root AGENTS.md #{message}")
    end
  end
end
if File.file?("CLAUDE.md") && File.file?("os/templates/root-CLAUDE.txt")
  add.call("root CLAUDE.md differs from its recovery template") unless File.read("CLAUDE.md") == File.read("os/templates/root-CLAUDE.txt")
end

allowed_roots = %w[.obsidian .codex .claude .agents AGENTS.md CLAUDE.md biz life os]
%w[.obsidian .codex .claude .agents].each do |path|
  notice.call("owner agent/app settings preserved: #{path}; review permissions before enabling, never execute during validation") if File.exist?(path)
end
%w[os life biz].each { |path| add.call("installed root may not be a symbolic link: #{path}") if Pathname.new(path).symlink? }
unexpected_roots = Dir.children(".").reject { |name| allowed_roots.include?(name) || IGNORED_COMPUTER_FILES.include?(name) }
notice.call("owner content at root: #{unexpected_roots.join(', ')}; review routing only with owner authority") unless unexpected_roots.empty?

empty_dirs = Dir.glob("**/*", File::FNM_DOTMATCH).select do |path|
  File.directory?(path) && !path.split("/").include?(".git") && Dir.children(path).empty?
end
empty_dirs.reject! { |path| path == "biz" || path == "biz/." || File.basename(path) == "." }
empty_dirs.each { |path| notice.call("owner empty directory retained: #{path}") }

Dir.glob("life/projects/*").select { |path| File.directory?(path) }.each do |project|
  name = File.basename(project)
  notice.call("custom project layout: #{project}; verify its owner-declared entry") unless File.file?(File.join(project, "#{name}.md"))
end

Dir.glob("biz/*").select { |path| File.directory?(path) }.each do |business|
  %w[AGENTS.md CLAUDE.md readme.md status.md knowledge-map.md decisions.md].each do |file|
    add.call("business foundation missing: #{business}/#{file}") unless File.file?(File.join(business, file))
  end
  nested = Dir.glob("#{business}/**/.git").reject { |path| path == "#{business}/.git" }
  nested.each { |path| add.call("nested business repository: #{path}") }

  history_check.call(business, "business #{business}")
end

skill_map = %w[os/skill-map.md os/owner-skills.md].select { |path| File.file?(path) && !path.split("/").include?(".git") && !symlink_component?(path) }.map { |path| File.read(path) }.join("\n")
actual_skills = Dir.glob("os/skills/*.md").map { |path| File.basename(path, ".md") }.reject { |name| name == "readme" }.sort
registrations = skill_map.scan(/^\|\s*\[\[([a-z0-9-]+)\]\]/).flatten
registrations.group_by(&:itself).each { |name, rows| add.call("duplicate skill registration: #{name}") if rows.length > 1 }
registered_skills = registrations.uniq.sort
(registered_skills - actual_skills).each { |skill| add.call("registered skill missing: os/skills/#{skill}.md") }
(actual_skills - registered_skills).each { |skill| add.call("unregistered skill file: os/skills/#{skill}.md") }

manual = File.file?("os/manual.md") ? File.read("os/manual.md") : ""
operating_rules = File.file?("os/AGENTS.md") ? File.read("os/AGENTS.md") : ""
add.call("manual is missing its human title") unless manual.include?("# How Starter.OS works")
add.call("manual does not explain Git, skills, automations, and updates") unless %w[Git Skills automations Update].all? { |word| manual.match?(/#{word}/i) }
add.call("manual is not declared protected") unless manual.match?(/may not rewrite|protected/i)
add.call("operating rules do not route explanations to the manual") unless operating_rules.match?(/Use .*manual\.md.*owner asks/im)
add.call("operating rules do not protect the manual") unless operating_rules.match?(/manual\.md.*protected/im) && operating_rules.match?(/Do not rewrite/im)

release_path = Pathname.new("os/release.json")
if release_path.file?
  begin
    release = JSON.parse(release_path.read)
    add.call("unsupported release record") unless release["format"] == 1 && release["product"] == "Starter.OS" && !release["version"].to_s.empty?
    release_artifacts = release.fetch("artifacts", {})
    add.call("release record has no artifacts") if release_artifacts.empty?
    release_artifacts.each do |path, record|
      target = Pathname.new(path)
      clean = target.cleanpath.to_s
      if target.absolute? || clean == ".." || clean.start_with?("../") || clean != path
        add.call("release record has unsafe path: #{path}")
        next
      end
      if symlink_component?(path)
        add.call("release artifact crosses a symbolic link: #{path}")
        next
      end
      absolute = Pathname.new(path)
      add.call("invalid ownership: #{path}") unless %w[managed owner-owned forked].include?(record["ownership"])
      if record["ownership"] == "managed"
        if !absolute.file?
          add.call("managed release artifact is missing: #{path}")
        elsif record["sha256"].to_s.empty?
          add.call("managed release artifact has no checksum: #{path}")
        elsif Digest::SHA256.file(absolute).hexdigest != record["sha256"]
          add.call("managed release artifact changed outside the update process: #{path}")
        end
      end
      add.call("root AGENTS.md must be owner-owned") if path == "AGENTS.md" && record["ownership"] != "owner-owned"
      add.call("protected product manual cannot be forked in place") if path == "os/manual.md" && record["ownership"] == "forked"
    end
    adoption = release["adoption"]
    if adoption && adoption["kind"] == "partial"
      notice.call("selected improvements from #{adoption['offered_version']}; base release remains #{release['version']}")
    end
    release_artifacts.each do |path, record|
      next unless record["ownership"] == "forked"
      available = record["available_upstream"]
      notice.call("owner fork retained: #{path}; upstream #{available && available['version'] || 'changes'} may be reviewed separately")
    end
    release.fetch("forks", []).each do |fork|
      destination = fork.fetch("destination")
      fork_path = Pathname.new(destination)
      clean = fork_path.cleanpath.to_s
      if fork_path.absolute? || clean == ".." || clean.start_with?("../") || clean != destination
        add.call("release record has unsafe fork destination: #{destination}")
        next
      end
      if symlink_component?(destination)
        add.call("declared owner fork crosses a symbolic link: #{destination}")
        next
      end
      if !fork_path.file?
        add.call("declared owner fork is missing: #{destination}")
      end
      if fork["source"] == "os/manual.md" && File.file?("os/me.md") && !File.read("os/me.md").include?(destination)
        add.call("manual fork is not routed from os/me.md: #{destination}")
      end
    end
  rescue JSON::ParserError => error
    add.call("release record is invalid JSON: #{error.message}")
  rescue KeyError => error
    add.call("release record is incomplete: #{error.message}")
  end
end

# Managed-file hashes enforce the shipped content. Validate user-visible contracts
# through release acceptance tests instead of requiring exact prose at runtime.
secret_shapes = {
  "private key" => /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  "GitHub token" => /(?:ghp|gho|github_pat)_[A-Za-z0-9_]{20,}/,
  "OpenAI key" => /sk-[A-Za-z0-9_-]{20,}/,
  "AWS key" => /AKIA[0-9A-Z]{16}/
}

Dir.glob("{os,life,biz}/**/*", File::FNM_DOTMATCH).select { |path| File.file?(path) && !path.split("/").include?(".git") && !symlink_component?(path) }.each do |path|
  text = File.binread(path).force_encoding(Encoding::UTF_8)
  next unless text.valid_encoding?
  secret_shapes.each { |label, pattern| add.call("#{path} contains #{label}-shaped text") if text.match?(pattern) }
end

if errors.empty?
  puts "PASS Starter.OS installed vault: structure, release identity, protected manual, skill registry, #{foundation_mode ? 'foundation protection notices' : 'readable local Git history'}, recurring workflow recipes, and privacy checks"
  notices.each { |message| puts "NOTICE #{message}" }
  puts "NOTE Foundation-only check requested; this is not proof of fully protected setup" if foundation_mode
  puts "NOTE Hosted primaries, mirrors, uncovered-file backups, and restore routes require separate verification in os/recovery.md"
  exit 0
end

puts "FAIL Starter.OS installed vault: #{errors.length} issue#{errors.length == 1 ? '' : 's'}"
errors.each { |message| puts "- #{message}" }
exit 1
