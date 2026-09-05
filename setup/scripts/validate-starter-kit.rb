#!/usr/bin/env ruby

require "digest"
require "fileutils"
require "find"
require "json"
require "open3"
require "pathname"
require "tmpdir"

ROOT = Pathname.new(File.expand_path("../..", __dir__))
Dir.chdir(ROOT)
TARGET_VERSION = JSON.parse(File.read("setup/release-manifest.json")).fetch("version")

errors = []
add = ->(message) { errors << message }

def capture(*command, chdir: nil)
  # These isolated fixtures intentionally exercise the local candidate. Owner
  # default refusal is covered independently without this helper.
  if command.any? { |arg| arg.to_s.end_with?("create-vault.rb") } || (command.any? { |arg| arg.to_s.end_with?("update-vault.rb") } && command.include?("apply"))
    command << "--allow-unreleased"
  end
  chdir ? Open3.capture2e(*command, chdir: chdir) : Open3.capture2e(*command)
end

def tree_digests(root)
  files = {}
  Find.find(root.to_s) do |absolute|
    relative = Pathname.new(absolute).relative_path_from(root).to_s
    if File.symlink?(absolute)
      files[relative] = "symlink:#{Digest::SHA256.hexdigest(File.readlink(absolute))}"
      next
    end
    if File.directory?(absolute)
      File.basename(absolute) == ".git" ? Find.prune : next
    end
    next unless File.file?(absolute)
    files[relative] = Digest::SHA256.file(absolute).hexdigest
  end
  files
end

source_before = tree_digests(ROOT)
history_update_proof = []
source_before.keys.select { |path| ROOT.join(path).symlink? }.each do |path|
  add.call("public source contains unsupported symbolic link: #{path}")
end

# Check meaningful source contracts and release inventory without freezing prose.
required = %w[AGENTS.md CLAUDE.md readme.md CHANGELOG.md LICENSE
  setup/AGENT-SETUP.md setup/UPDATE.md setup/GIT-SETUP.md
  setup/scripts/create-vault.rb setup/scripts/update-vault.rb setup/scripts/restore-vault.rb
  setup/scripts/update-support.rb setup/scripts/validate-source.rb setup/scripts/test-update-contract.rb
  os/owner-skills.md os/skill-map.md os/manual.md]
required.each { |path| add.call("missing #{path}") unless File.file?(path) }
%w[setup/START-HERE.md setup/QUICK-SETUP.md setup/MIGRATE.md setup/scripts/verify-migration.rb].each do |path|
  add.call("retired source path remains: #{path}") if File.exist?(path)
end
readme = File.read("readme.md")
root_agents = File.read("AGENTS.md")
agent_setup = File.read("setup/AGENT-SETUP.md")
update = File.read("setup/UPDATE.md")
git_setup = File.read("setup/GIT-SETUP.md")
add.call("ordinary-prompt entry is missing") unless readme.include?("find the install that fits us best") && root_agents.include?("find the install that fits us best")
add.call("owner setup must not require a task") unless agent_setup.include?("No real task")
add.call("updates must require an agreed plan") unless update.include?("apply only the agreed plan") || update.include?("Apply only the agreed plan")
add.call("setup lacks a real protection opt-out") unless git_setup.include?("all Git is declined or deferred")
add.call("manual title missing") unless File.read("os/manual.md").include?("# How Starter.OS works")
add.call("MIT code license missing") unless File.read("setup/legal/LICENSE-CODE").include?("MIT License")
add.call("CC BY content license missing") unless File.read("setup/legal/LICENSE-CONTENT").match?(/Creative\s+Commons\s+Attribution\s+4\.0\s+International/m)
manifest = JSON.parse(File.read("setup/release-manifest.json"))
add.call("unsupported release manifest") unless manifest["format"] == 1 && manifest["product"] == "Starter.OS"
required_starts = %w[unversioned-legacy 2.0.0 2.1.0 3.0.0]
add.call("declared prior transitions incomplete") unless (required_starts - manifest.fetch("supported_updates")).empty?
add.call("invalid release state") unless %w[unreleased released].include?(manifest["status"])
add.call("candidate has a fabricated release date") if manifest["status"] == "unreleased" && manifest["released"]
if manifest["status"] == "released"
  add.call("released source needs a date and versioned changelog") unless manifest["released"] && File.read("CHANGELOG.md").include?("## [#{TARGET_VERSION}] - #{manifest['released']}")
end
artifacts = manifest.fetch("artifacts")
paths = artifacts.map { |artifact| artifact.fetch("path") }
add.call("duplicate installed paths") unless paths.uniq == paths
artifacts.each do |artifact|
  add.call("invalid ownership #{artifact['path']}") unless %w[managed owner-owned].include?(artifact["ownership"])
  add.call("undeclared group #{artifact['path']}") unless manifest.fetch("update_groups").key?(artifact["update_group"])
end
expected_installed = Dir.glob("{os,life}/**/*", File::FNM_DOTMATCH).select { |path| File.file?(path) } - ["os/release.json"]
expected_installed += %w[AGENTS.md CLAUDE.md os/scripts/add-project.rb os/scripts/add-business.rb]
add.call("installed artifact inventory differs from source") unless paths.sort == expected_installed.sort
expected_distribution = tree_digests(ROOT).reject { |path, _| path == "setup/release-manifest.json" }
recorded_distribution = manifest.fetch("distribution_files").to_h { |entry| [entry.fetch("path"), entry.fetch("sha256")] }
add.call("public distribution inventory/checksums differ") unless expected_distribution == recorded_distribution

source_files = tree_digests(ROOT).keys
secret_shapes = {
  "private key" => /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,
  "GitHub token" => /(?:ghp|gho|github_pat)_[A-Za-z0-9_]{20,}/,
  "OpenAI key" => /sk-[A-Za-z0-9_-]{20,}/,
  "AWS key" => /AKIA[0-9A-Z]{16}/
}
source_files.each do |path|
  next if File.symlink?(path)
  text = File.binread(path).force_encoding(Encoding::UTF_8)
  next unless text.valid_encoding?
  next if path == "setup/scripts/validate-starter-kit.rb"
  secret_shapes.each { |label, pattern| add.call("#{path} contains #{label}-shaped text") if text.match?(pattern) }
  add.call("#{path} exposes a private local path") if text.match?(%r{/Users/[^/\s]+/})
end

synthetic_secrets = {
  "private key" => "-----BEGIN PRIVATE KEY-----",
  "GitHub token" => "ghp_abcdefghijklmnopqrstuvwxyz123456",
  "OpenAI key" => "sk-abcdefghijklmnopqrstuvwxyz123456",
  "AWS key" => "AKIA1234567890ABCDEF"
}
secret_shapes.each do |label, pattern|
  add.call("secret scanner positive fixture failed: #{label}") unless synthetic_secrets.fetch(label).match?(pattern)
end

source_files.select { |path| path.end_with?(".md") }.each do |path|
  File.read(path).scan(/\[[^\]]+\]\(([^)]+)\)/).flatten.each do |target|
    clean = target.split("#", 2).first
    next if clean.empty? || clean.match?(/\A(?:https?:|mailto:)/)
    resolved = File.expand_path(clean, File.dirname(path))
    add.call("#{path} links to missing #{target}") unless File.exist?(resolved)
  end
end

Dir.glob("os/skills/*.md").each do |path|
  File.read(path).scan(/\[\[([a-z0-9-]+)\]\]/).flatten.each do |target|
    add.call("#{path} links to missing skill #{target}") unless File.file?("os/skills/#{target}.md")
  end
end

source_check_output, source_check_status = capture("ruby", "setup/scripts/validate-source.rb")
add.call("owner source check failed: #{source_check_output.strip}") unless source_check_status.success?

source_project_output, source_project_status = capture("ruby", "setup/scripts/add-project.rb", "must-refuse")
add.call("project generator did not refuse the public source") if source_project_status.success? || File.exist?("life/projects/must-refuse")
source_business_output, source_business_status = capture("ruby", "setup/scripts/add-business.rb", "must-refuse")
add.call("business generator did not refuse the public source") if source_business_status.success? || File.exist?("biz/must-refuse")

Dir.mktmpdir("starter-os-3-") do |tmp|
  source_fixture = File.join(tmp, "SOURCE-CHECK")
  FileUtils.mkdir_p(source_fixture)
  ROOT.children.each do |entry|
    next if entry.basename.to_s == ".git"
    FileUtils.cp_r(entry, source_fixture)
  end
  zip_project_output, zip_project_status = capture("ruby", "setup/scripts/add-project.rb", "must-refuse", chdir: source_fixture)
  if zip_project_status.success? || File.exist?(File.join(source_fixture, "life", "projects", "must-refuse"))
    add.call("project generator wrote into a public source without Git metadata: #{zip_project_output.strip}")
  end
  zip_business_output, zip_business_status = capture("ruby", "setup/scripts/add-business.rb", "must-refuse", chdir: source_fixture)
  if zip_business_status.success? || File.exist?(File.join(source_fixture, "biz", "must-refuse"))
    add.call("business generator wrote into a public source without Git metadata: #{zip_business_output.strip}")
  end
  %w[.DS_Store .localized Thumbs.db desktop.ini].each do |name|
    File.write(File.join(source_fixture, name), "harmless computer metadata fixture\n")
  end
  metadata_source_output, metadata_source_status = capture("ruby", "setup/scripts/validate-source.rb", chdir: source_fixture)
  add.call("owner source check rejected harmless computer metadata: #{metadata_source_output.strip}") unless metadata_source_status.success?

  nested_metadata = File.join(source_fixture, "setup", "scripts", ".DS_Store")
  File.write(nested_metadata, "unexpected nested metadata fixture\n")
  nested_metadata_output, nested_metadata_status = capture("ruby", "setup/scripts/validate-source.rb", chdir: source_fixture)
  add.call("owner source check rejected harmless nested computer metadata: #{nested_metadata_output.strip}") unless nested_metadata_status.success?
  FileUtils.rm_f(nested_metadata)

  local_tool_directory = File.join(source_fixture, ".codex")
  FileUtils.mkdir_p(local_tool_directory)
  File.write(File.join(local_tool_directory, "session.log"), "local tool state\n")
  local_tool_output, local_tool_status = capture("ruby", "setup/scripts/validate-source.rb", chdir: source_fixture)
  if local_tool_status.success? || !local_tool_output.include?("unexpected agent-configuration folder in the public copy: .codex")
    add.call("owner source check silently accepted agent configuration: #{local_tool_output.strip}")
  end
  FileUtils.rm_rf(local_tool_directory)

  private_environment = File.join(source_fixture, ".env")
  File.write(private_environment, "PRIVATE_VALUE=must-not-be-ignored-by-source-safety\n")
  private_environment_output, private_environment_status = capture("ruby", "setup/scripts/validate-source.rb", chdir: source_fixture)
  if private_environment_status.success? || !private_environment_output.include?("unexpected public files are present: .env")
    add.call("owner source check ignored a private environment file")
  end
  FileUtils.rm_f(private_environment)

  extra_source_path = File.join(source_fixture, "unexpected-owner-file.md")
  File.write(extra_source_path, "unexpected public file fixture\n")
  extra_source_output, extra_source_status = capture("ruby", "setup/scripts/validate-source.rb", chdir: source_fixture)
  if extra_source_status.success? || !extra_source_output.include?("unexpected public files are present: unexpected-owner-file.md")
    add.call("owner source check accepted an unexpected public file")
  end
  FileUtils.rm_f(extra_source_path)

  missing_source_path = File.join(source_fixture, "setup", "GIT-SETUP.md")
  missing_source_bytes = File.binread(missing_source_path)
  FileUtils.rm_f(missing_source_path)
  missing_source_output, missing_source_status = capture("ruby", "setup/scripts/validate-source.rb", chdir: source_fixture)
  if missing_source_status.success? || !missing_source_output.include?("public files are missing: setup/GIT-SETUP.md")
    add.call("owner source check accepted a missing public file")
  end
  File.binwrite(missing_source_path, missing_source_bytes)

  File.open(File.join(source_fixture, "os", "manual.md"), "a") { |file| file.write("\ntampered source fixture\n") }
  tampered_source_output, tampered_source_status = capture("ruby", "setup/scripts/validate-source.rb", chdir: source_fixture)
  if tampered_source_status.success? || !tampered_source_output.include?("public files do not match Starter.OS: os/manual.md")
    add.call("owner source check accepted a changed public file")
  end

  init_repository = lambda do |repository|
    commands = [
      ["git", "init", "-q", repository],
      ["git", "-C", repository, "config", "user.name", "Starter.OS test"],
      ["git", "-C", repository, "config", "user.email", "starter-os-test@example.invalid"],
      ["git", "-C", repository, "add", "-A"],
      ["git", "-C", repository, "commit", "-q", "-m", "test recovery point"]
    ]
    commands.each do |command|
      output, status = capture(*command)
      add.call("test Git setup failed: #{command.join(' ')}: #{output.strip}") unless status.success?
    end
  end

  init_git = lambda do |vault|
    %w[os life].each { |name| init_repository.call(File.join(vault, name)) }
  end

  git_state = lambda do |repository|
    head, head_status = capture("git", "-C", repository, "rev-parse", "HEAD")
    status_output, status_status = capture("git", "-C", repository, "status", "--porcelain")
    config, config_status = capture("git", "-C", repository, "config", "--local", "--list")
    unless head_status.success? && status_status.success? && config_status.success?
      add.call("could not read test Git state for #{repository}")
    end
    { "head" => head, "status" => status_output, "config" => config }
  end

  build_historical_vault = lambda do |ref, destination|
    manifest_text, manifest_status = capture("git", "show", "#{ref}:release-manifest.json")
    manifest_text, manifest_status = capture("git", "show", "#{ref}:setup/release-manifest.json") unless manifest_status.success?
    unless manifest_status.success?
      add.call("historical release proof is unavailable for #{ref}")
      next nil
    end

    historical_manifest = JSON.parse(manifest_text)
    FileUtils.mkdir_p(destination)
    historical_manifest.fetch("directories", []).each { |path| FileUtils.mkdir_p(File.join(destination, path)) }

    installed_artifacts = {}
    historical_manifest.fetch("artifacts").each do |artifact|
      source = artifact.fetch("source")
      target = artifact.fetch("path")
      bytes, source_status = capture("git", "show", "#{ref}:#{source}")
      unless source_status.success?
        add.call("cannot read historical #{historical_manifest['version']} source #{source} from #{ref}")
        next
      end
      if Digest::SHA256.hexdigest(bytes) != artifact.fetch("sha256")
        add.call("historical #{historical_manifest['version']} source checksum differs: #{source}")
      end
      bytes = bytes.gsub("{{SYSTEM_NAME}}", File.basename(destination)) if artifact["render"] == "system-name"
      target_path = File.join(destination, target)
      FileUtils.mkdir_p(File.dirname(target_path))
      File.binwrite(target_path, bytes)
      installed_artifacts[target] = {
        "ownership" => artifact.fetch("ownership"),
        "sha256" => Digest::SHA256.hexdigest(bytes),
        "upstream_sha256" => artifact.fetch("sha256"),
        "source_version" => historical_manifest.fetch("version")
      }
    end

    release_record = {
      "format" => 1,
      "product" => "Starter.OS",
      "version" => historical_manifest.fetch("version"),
      "installed_at" => "historical validation fixture",
      "manifest_sha256" => Digest::SHA256.hexdigest(manifest_text),
      "artifacts" => installed_artifacts
    }
    File.write(File.join(destination, "os", "release.json"), "#{JSON.pretty_generate(release_record)}\n")
    historical_manifest.fetch("version")
  rescue JSON::ParserError, KeyError => error
    add.call("historical fixture from #{ref} is invalid: #{error.message}")
    nil
  end

  manifest.fetch("historical_sources").each do |version, ref|
    historical_vault = File.join(tmp, "HISTORY-#{version}.os")
    built_version = build_historical_vault.call(ref, historical_vault)
    next unless built_version

    add.call("historical fixture version mismatch for #{ref}: #{built_version}") unless built_version == version
    owner_path = File.join(historical_vault, "life", "historical-owner-note.md")
    File.write(owner_path, "owner work from #{version} must survive\n")
    owner_digest = Digest::SHA256.file(owner_path).hexdigest
    init_git.call(historical_vault)

    historical_plan = File.join(tmp, "history-#{version}-plan.json")
    plan_output, plan_status = capture("ruby", "setup/scripts/update-vault.rb", "plan", historical_vault, historical_plan)
    add.call("history-backed #{version} update plan failed: #{plan_output.strip}") unless plan_status.success?
    next unless plan_status.success?

    plan = JSON.parse(File.read(historical_plan))
    conflicts = plan.fetch("entries").select { |entry| entry["action"] == "conflict" }
    add.call("history-backed #{version} update has unexpected conflicts: #{conflicts.map { |entry| entry['path'] }.join(', ')}") unless conflicts.empty?
    historical_root_entry = plan.fetch("entries").find { |entry| entry["path"] == "AGENTS.md" }
    add.call("history-backed #{version} update did not plan the root ownership transfer") unless historical_root_entry && historical_root_entry["action"] == (version == "3.0.0" ? "preserve" : "adopt-owner-entry")
    historical_root_backup = File.join(tmp, "history-#{version}-root-backup")
    apply_output, apply_status = capture(
      "ruby", "setup/scripts/update-vault.rb", "apply", historical_vault, historical_plan,
      "--root-backup", historical_root_backup
    )
    add.call("history-backed #{version} update apply failed: #{apply_output.strip}") unless apply_status.success?
    next unless apply_status.success?

    add.call("history-backed #{version} update changed owner work") unless Digest::SHA256.file(owner_path).hexdigest == owner_digest
    installed_release = JSON.parse(File.read(File.join(historical_vault, "os", "release.json")))
    add.call("history-backed #{version} update did not install #{TARGET_VERSION}") unless installed_release["version"] == TARGET_VERSION
    add.call("history-backed #{version} update did not make the root entry owner-owned") unless installed_release.dig("artifacts", "AGENTS.md", "ownership") == "owner-owned"
    updated_root = File.read(File.join(historical_vault, "AGENTS.md"))
    add.call("history-backed #{version} update did not name the private root entry") unless updated_root.include?("# HISTORY-#{version}.os agent entry")
    installed_output, installed_status = capture("ruby", "os/validate-starter-os.rb", chdir: historical_vault)
    add.call("history-backed #{version} update did not validate: #{installed_output.strip}") unless installed_status.success?
    history_update_proof << version
  end

  missing_history = manifest.fetch("historical_sources").keys - history_update_proof
  add.call("historical update proof did not complete for: #{missing_history.join(', ')}") unless missing_history.empty?

  linked_install_target = File.join(tmp, "LINKED-INSTALL-TARGET.os")
  linked_install = File.join(tmp, "LINKED-INSTALL.os")
  FileUtils.mkdir_p(linked_install_target)
  File.symlink(linked_install_target, linked_install)
  linked_install_output, linked_install_status = capture("ruby", "setup/scripts/create-vault.rb", linked_install)
  if linked_install_status.success? || !linked_install_output.include?("destination itself may not be a symbolic link")
    add.call("clean installer did not reject a symbolic-link destination root")
  end

  builder_fixture = File.join(tmp, "builder-fixture")
  FileUtils.mkdir_p(builder_fixture)
  %w[os life setup].each { |path| FileUtils.cp_r(ROOT.join(path), builder_fixture) }
  builder_external = File.join(tmp, "builder-external")
  FileUtils.mkdir_p(builder_external)
  File.write(File.join(builder_external, "outside.md"), "outside release tree\n")
  File.symlink(builder_external, File.join(builder_fixture, "os", "linked-outside"))
  builder_output, builder_status = capture(
    "ruby", "setup/scripts/build-release-manifest.rb",
    chdir: builder_fixture
  )
  if builder_status.success? || !builder_output.include?("symbolic links are not allowed")
    add.call("release manifest builder did not reject a symbolic-link directory")
  end

  vault = File.join(tmp, "NOVA.os")
  output, status = capture("ruby", "setup/scripts/create-vault.rb", vault)
  add.call("clean install failed: #{output.strip}") unless status.success?

  if status.success?
    roots = Dir.children(vault).sort
    expected_roots = %w[AGENTS.md CLAUDE.md biz life os]
    add.call("generated roots differ: #{roots.join(', ')}") unless roots == expected_roots
    add.call("setup leaked into installed vault") if File.exist?(File.join(vault, "setup"))
    add.call("biz is not initially empty") unless Dir.children(File.join(vault, "biz")).empty?
    add.call("manual was not installed") unless File.file?(File.join(vault, "os", "manual.md"))
    add.call("license was not installed") unless File.file?(File.join(vault, "os", "license.md"))

    release = JSON.parse(File.read(File.join(vault, "os", "release.json")))
    add.call("installed release version is not #{TARGET_VERSION}") unless release["version"] == TARGET_VERSION
    root_entry_path = File.join(vault, "AGENTS.md")
    root_entry = File.read(root_entry_path)
    add.call("clean install did not name the private root entry") unless root_entry.include?("# NOVA.os agent entry")
    add.call("clean install left an unresolved system-name marker") if root_entry.include?("{{SYSTEM_NAME}}")
    add.call("public Starter.OS dispatcher leaked into the private root entry") if root_entry.include?("setup/release-manifest.json")
    add.call("installed root entry is not recorded as owner-owned") unless release.dig("artifacts", "AGENTS.md", "ownership") == "owner-owned"

    unprotected_vault_output, unprotected_vault_status = capture("ruby", "os/validate-starter-os.rb", chdir: vault)
    if unprotected_vault_status.success? || !unprotected_vault_output.include?("os/ is not protected by its own Git repository") || !unprotected_vault_output.include?("life/ is not protected by its own Git repository")
      add.call("installed validator accepted os/ or life/ without independent Git history")
    end

    init_git.call(vault)

    project_output, project_status = capture("ruby", "os/scripts/add-project.rb", "health", chdir: vault)
    add.call("project generator failed: #{project_output.strip}") unless project_status.success?
    if project_status.success?
      life_root = File.join(vault, "life")
      capture("git", "-C", life_root, "add", "-A")
      project_commit_output, project_commit_status = capture("git", "-C", life_root, "commit", "-q", "-m", "add test project")
      add.call("test project recovery commit failed: #{project_commit_output.strip}") unless project_commit_status.success?
    end
    business_output, business_status = capture("ruby", "os/scripts/add-business.rb", "sample-studio", chdir: vault)
    add.call("business generator failed: #{business_output.strip}") unless business_status.success?
    if business_status.success?
      unprotected_business_output, unprotected_business_status = capture("ruby", "os/validate-starter-os.rb", chdir: vault)
      if unprotected_business_status.success? || !unprotected_business_output.include?("business biz/sample-studio is not protected by its own Git repository")
        add.call("installed validator accepted a business without its own Git repository")
      end
      capture("git", "init", "-q", File.join(vault, "biz", "sample-studio"))
      unborn_business_output, unborn_business_status = capture("ruby", "os/validate-starter-os.rb", chdir: vault)
      if unborn_business_status.success? || !unborn_business_output.include?("business biz/sample-studio has no readable recovery commit")
        add.call("installed validator accepted a business Git repository without a commit")
      end
      init_repository.call(File.join(vault, "biz", "sample-studio"))
    end

    validate_output, validate_status = capture("ruby", "os/validate-starter-os.rb", chdir: vault)
    add.call("installed validation failed:\n#{validate_output}") unless validate_status.success?

    File.open(root_entry_path, "a") { |file| file.write("\nOwner-approved root note.\n") }
    customized_root_digest = Digest::SHA256.file(root_entry_path).hexdigest
    customized_validate_output, customized_validate_status = capture("ruby", "os/validate-starter-os.rb", chdir: vault)
    add.call("installed validator rejected an owner-customized root entry: #{customized_validate_output.strip}") unless customized_validate_status.success?

    %w[.DS_Store .localized Thumbs.db desktop.ini].each do |name|
      File.write(File.join(vault, name), "harmless computer metadata fixture\n")
    end
    metadata_output, metadata_status = capture("ruby", "os/validate-starter-os.rb", chdir: vault)
    add.call("installed validation rejected harmless computer-created root files: #{metadata_output.strip}") unless metadata_status.success?
    File.write(File.join(vault, "unexpected-owner-file.md"), "unexpected root fixture\n")
    unexpected_root_output, unexpected_root_status = capture("ruby", "os/validate-starter-os.rb", chdir: vault)
    if !unexpected_root_status.success? || !unexpected_root_output.include?("owner content at root: unexpected-owner-file.md")
      add.call("installed validation failed to preserve and report owner root content")
    end
    FileUtils.rm_f(File.join(vault, "unexpected-owner-file.md"))

    external_manual = File.join(tmp, "external-manual.md")
    installed_manual = File.join(vault, "os", "manual.md")
    manual_bytes = File.binread(installed_manual)
    File.binwrite(external_manual, manual_bytes)
    FileUtils.rm_f(installed_manual)
    File.symlink(external_manual, installed_manual)
    linked_validate_output, linked_validate_status = capture("ruby", "os/validate-starter-os.rb", chdir: vault)
    if linked_validate_status.success? || !linked_validate_output.include?("crosses a symbolic link")
      add.call("installed validator did not reject a managed symbolic link")
    end
    FileUtils.rm_f(installed_manual)
    File.binwrite(installed_manual, manual_bytes)

    linked_update_target = File.join(tmp, "LINKED-UPDATE.os")
    File.symlink(vault, linked_update_target)
    linked_plan_path = File.join(tmp, "linked-update-plan.json")
    linked_plan_output, linked_plan_status = capture(
      "ruby", "setup/scripts/update-vault.rb", "plan",
      linked_update_target, linked_plan_path
    )
    if linked_plan_status.success? || !linked_plan_output.include?("target itself may not be a symbolic link")
      add.call("updater did not reject a symbolic-link target root")
    end

    linked_plan_parent = File.join(tmp, "LINKED-PLAN-PARENT")
    File.symlink(File.join(vault, "os"), linked_plan_parent)
    linked_output_path = File.join(linked_plan_parent, "update-plan.json")
    linked_output, linked_output_status = capture(
      "ruby", "setup/scripts/update-vault.rb", "plan", vault, linked_output_path
    )
    if linked_output_status.success? || !linked_output.include?("plan output crosses a symbolic link")
      add.call("updater accepted a plan output routed through a symbolic-link directory")
    end

    plan_path = File.join(tmp, "same-version-plan.json")
    plan_output, plan_status = capture("ruby", "setup/scripts/update-vault.rb", "plan", vault, plan_path)
    add.call("same-version update plan failed: #{plan_output.strip}") unless plan_status.success?
    if plan_status.success?
      plan = JSON.parse(File.read(plan_path))
      add.call("same-version plan unexpectedly has conflicts") if plan["entries"].any? { |entry| entry["action"] == "conflict" }
      root_plan_entry = plan["entries"].find { |entry| entry["path"] == "AGENTS.md" }
      add.call("same-version update did not preserve the owner root entry") unless root_plan_entry && root_plan_entry["action"] == "preserve"

      tampered_path = File.join(tmp, "tampered-plan.json")
      tampered = JSON.parse(JSON.generate(plan))
      preserve_entry = tampered.fetch("entries").find { |entry| entry["action"] == "preserve" }
      if preserve_entry
        protected_path = File.join(vault, preserve_entry.fetch("path"))
        protected_before = Digest::SHA256.file(protected_path).hexdigest
        preserve_entry["action"] = "update"
        File.write(tampered_path, "#{JSON.pretty_generate(tampered)}\n")
        tampered_output, tampered_status = capture(
          "ruby", "setup/scripts/update-vault.rb", "apply",
          vault, tampered_path
        )
        if tampered_status.success? || !tampered_output.include?("plan contents do not match")
          add.call("updater did not reject a semantically tampered plan")
        end
        add.call("tampered update plan changed an owner-owned file") unless Digest::SHA256.file(protected_path).hexdigest == protected_before
      else
        add.call("same-version plan has no owner-owned preserve entry for tamper regression")
      end

      dirty_life_path = File.join(vault, "life", "unprotected-update-test.md")
      File.write(dirty_life_path, "must block update\n")
      dirty_life_output, dirty_life_status = capture("ruby", "setup/scripts/update-vault.rb", "apply", vault, plan_path)
      if dirty_life_status.success? || !dirty_life_output.match?(/life\/ has uncommitted work|plan contents do not match/)
        add.call("updater did not reject uncommitted life/ work")
      end
      FileUtils.rm_f(dirty_life_path)

      same_version_root_backup = File.join(tmp, "same-version-root-backup")
      apply_output, apply_status = capture(
        "ruby", "setup/scripts/update-vault.rb", "apply", vault, plan_path,
        "--root-backup", same_version_root_backup
      )
      add.call("same-version update apply failed: #{apply_output.strip}") unless apply_status.success?
      add.call("same-version update changed the owner root entry") unless Digest::SHA256.file(root_entry_path).hexdigest == customized_root_digest
      add.call("no-change update unnecessarily created a backup") if File.exist?(same_version_root_backup)
    end

    unborn_update_vault = File.join(tmp, "UNBORN-UPDATE.os")
    unborn_create_output, unborn_create_status = capture("ruby", "setup/scripts/create-vault.rb", unborn_update_vault)
    add.call("unborn update fixture could not be created: #{unborn_create_output.strip}") unless unborn_create_status.success?
    if unborn_create_status.success?
      %w[os life].each do |name|
        repository = File.join(unborn_update_vault, name)
        capture("git", "init", "-q", repository)
        File.write(File.join(repository, ".git", "info", "exclude"), "*\n")
      end
      unborn_plan = File.join(tmp, "unborn-update-plan.json")
      unborn_plan_output, unborn_plan_status = capture("ruby", "setup/scripts/update-vault.rb", "plan", unborn_update_vault, unborn_plan)
      add.call("unborn update plan failed unexpectedly: #{unborn_plan_output.strip}") unless unborn_plan_status.success?
      if unborn_plan_status.success?
        unborn_apply_output, unborn_apply_status = capture("ruby", "setup/scripts/update-vault.rb", "apply", unborn_update_vault, unborn_plan)
        if unborn_apply_status.success? || !unborn_apply_output.include?("has no readable recovery commit")
          add.call("updater accepted clean Git repositories without recovery commits")
        end
      end
    end

    refusal_output, refusal_status = capture("ruby", "setup/scripts/create-vault.rb", vault)
    add.call("non-empty destination was not refused") if refusal_status.success? || !refusal_output.include?("not empty")
  end

  prior_vault = File.join(tmp, "STARTER-2-0.os")
  prior_create, prior_create_status = capture("ruby", "setup/scripts/create-vault.rb", prior_vault)
  if prior_create_status.success?
    prior_release_path = File.join(prior_vault, "os", "release.json")
    prior_release = JSON.parse(File.read(prior_release_path))
    prior_release["version"] = "2.0.0"
    prior_brief_path = File.join(prior_vault, "os", "skills", "daily-brief.md")
    prior_brief = "---\ntype: skill\nstatus: draft\n---\n\n# daily brief\n\nLegacy 2.0 fixture.\n"
    File.write(prior_brief_path, prior_brief)
    prior_release.fetch("artifacts").fetch("os/skills/daily-brief.md")["sha256"] = Digest::SHA256.hexdigest(prior_brief)
    File.write(prior_release_path, "#{JSON.pretty_generate(prior_release)}\n")
    custom_path = File.join(prior_vault, "life", "original-owner-note.md")
    File.write(custom_path, "owner work must survive\n")
    custom_digest = Digest::SHA256.file(custom_path).hexdigest
    init_git.call(prior_vault)

    prior_plan_path = File.join(tmp, "2-0-to-3-0-plan.json")
    prior_plan_output, prior_plan_status = capture("ruby", "setup/scripts/update-vault.rb", "plan", prior_vault, prior_plan_path)
    add.call("2.0 to 3.0 update plan failed: #{prior_plan_output.strip}") unless prior_plan_status.success?
    if prior_plan_status.success?
      prior_plan = JSON.parse(File.read(prior_plan_path))
      brief_entry = prior_plan.fetch("entries").find { |entry| entry["path"] == "os/skills/daily-brief.md" }
      add.call("2.0 to 3.0 plan did not recognize the managed Morning Brief update") unless brief_entry && brief_entry["action"] == "update"
      prior_apply_output, prior_apply_status = capture(
        "ruby", "setup/scripts/update-vault.rb", "apply", prior_vault, prior_plan_path,
        "--root-backup", File.join(tmp, "representative-2-0-root-backup")
      )
      add.call("2.0 to 3.0 update apply failed: #{prior_apply_output.strip}") unless prior_apply_status.success?
      if prior_apply_status.success?
        updated_release = JSON.parse(File.read(prior_release_path))
        add.call("2.0 update did not install #{TARGET_VERSION}") unless updated_release["version"] == TARGET_VERSION
        add.call("2.0 update changed unknown owner work") unless Digest::SHA256.file(custom_path).hexdigest == custom_digest
        prior_validate, prior_validate_status = capture("ruby", "os/validate-starter-os.rb", chdir: prior_vault)
        add.call("updated 2.0 vault did not validate: #{prior_validate.strip}") unless prior_validate_status.success?
      end
    end
  else
    add.call("2.0 update fixture could not be created: #{prior_create.strip}")
  end

  starter_2_1 = File.join(tmp, "STARTER-2-1.os")
  starter_2_1_create, starter_2_1_create_status = capture("ruby", "setup/scripts/create-vault.rb", starter_2_1)
  if starter_2_1_create_status.success?
    starter_2_1_release_path = File.join(starter_2_1, "os", "release.json")
    starter_2_1_release = JSON.parse(File.read(starter_2_1_release_path))
    starter_2_1_release["version"] = "2.1.0"
    starter_2_1_root_path = File.join(starter_2_1, "AGENTS.md")
    starter_2_1_release.fetch("artifacts").fetch("AGENTS.md")["ownership"] = "managed"
    starter_2_1_root_seed, starter_2_1_root_seed_status = capture("git", "show", "v2.1.0:os/templates/root-AGENTS.txt")
    add.call("customized 2.1 root fixture is unavailable from real history") unless starter_2_1_root_seed_status.success?
    starter_2_1_release.fetch("artifacts").fetch("AGENTS.md")["sha256"] = Digest::SHA256.hexdigest(starter_2_1_root_seed)
    File.binwrite(starter_2_1_root_path, "#{starter_2_1_root_seed}\nOwner customization from 2.1.\n")
    starter_2_1_root_digest = Digest::SHA256.file(starter_2_1_root_path).hexdigest
    prior_agents_path = File.join(starter_2_1, "os", "AGENTS.md")
    prior_agents = "# Operating rules\n\nRepresentative managed Starter.OS 2.1 fixture.\n"
    File.write(prior_agents_path, prior_agents)
    starter_2_1_release.fetch("artifacts").fetch("os/AGENTS.md")["sha256"] = Digest::SHA256.hexdigest(prior_agents)
    File.write(starter_2_1_release_path, "#{JSON.pretty_generate(starter_2_1_release)}\n")
    starter_2_1_owner_path = File.join(starter_2_1, "life", "owner-2-1-note.md")
    File.write(starter_2_1_owner_path, "owner work from 2.1 must survive\n")
    starter_2_1_owner_digest = Digest::SHA256.file(starter_2_1_owner_path).hexdigest
    init_git.call(starter_2_1)

    starter_2_1_plan = File.join(tmp, "2-1-to-3-0-plan.json")
    starter_2_1_plan_output, starter_2_1_plan_status = capture("ruby", "setup/scripts/update-vault.rb", "plan", starter_2_1, starter_2_1_plan)
    add.call("2.1 to 3.0 update plan failed: #{starter_2_1_plan_output.strip}") unless starter_2_1_plan_status.success?
    if starter_2_1_plan_status.success?
      plan = JSON.parse(File.read(starter_2_1_plan))
      agents_entry = plan.fetch("entries").find { |entry| entry["path"] == "os/AGENTS.md" }
      add.call("2.1 to 3.0 plan did not recognize a managed instruction update") unless agents_entry && agents_entry["action"] == "update"
      root_entry = plan.fetch("entries").find { |entry| entry["path"] == "AGENTS.md" }
      add.call("2.1 to 3.0 plan did not preserve a customized root entry") unless root_entry && root_entry["action"] == "preserve"
      starter_2_1_apply_output, starter_2_1_apply_status = capture(
        "ruby", "setup/scripts/update-vault.rb", "apply", starter_2_1, starter_2_1_plan,
        "--root-backup", File.join(tmp, "representative-2-1-root-backup")
      )
      add.call("2.1 to 3.0 update apply failed: #{starter_2_1_apply_output.strip}") unless starter_2_1_apply_status.success?
      if starter_2_1_apply_status.success?
        updated_release = JSON.parse(File.read(starter_2_1_release_path))
        add.call("2.1 update did not install #{TARGET_VERSION}") unless updated_release["version"] == TARGET_VERSION
        add.call("2.1 update changed unknown owner work") unless Digest::SHA256.file(starter_2_1_owner_path).hexdigest == starter_2_1_owner_digest
        add.call("2.1 update changed a customized root entry") unless Digest::SHA256.file(starter_2_1_root_path).hexdigest == starter_2_1_root_digest
        add.call("2.1 update did not transfer customized root ownership") unless updated_release.dig("artifacts", "AGENTS.md", "ownership") == "owner-owned"
        starter_2_1_validate, starter_2_1_validate_status = capture("ruby", "os/validate-starter-os.rb", chdir: starter_2_1)
        add.call("preserved historical 2.1 root prevented installed validation: #{starter_2_1_validate.strip}") unless starter_2_1_validate_status.success?
        add.call("preserved historical 2.1 root did not produce a reconciliation notice") unless starter_2_1_validate.include?("NOTICE preserved owner root AGENTS.md")
      end
    end
  else
    add.call("2.1 update fixture could not be created: #{starter_2_1_create.strip}")
  end

  fork_vault = File.join(tmp, "FORK.os")
  fork_create, fork_create_status = capture("ruby", "setup/scripts/create-vault.rb", fork_vault)
  if fork_create_status.success?
    init_git.call(fork_vault)
    File.open(File.join(fork_vault, "os", "manual.md"), "a") { |file| file.write("\nOwner explanation.\n") }
    capture("git", "-C", File.join(fork_vault, "os"), "add", "-A")
    capture("git", "-C", File.join(fork_vault, "os"), "commit", "-q", "-m", "owner changed manual")
    fork_plan = File.join(tmp, "fork-plan.json")
    fork_plan_output, fork_plan_status = capture("ruby", "setup/scripts/update-vault.rb", "plan", fork_vault, fork_plan)
    add.call("manual conflict plan failed: #{fork_plan_output.strip}") unless fork_plan_status.success?
    if fork_plan_status.success?
      plan = JSON.parse(File.read(fork_plan))
      manual_entry = plan["entries"].find { |entry| entry["path"] == "os/manual.md" }
      add.call("modified manual was not detected as a conflict") unless manual_entry && manual_entry["action"] == "conflict"
      fork_apply_output, fork_apply_status = capture(
        "ruby", "setup/scripts/update-vault.rb", "apply", fork_vault, fork_plan,
        "--root-backup", File.join(tmp, "manual-fork-root-backup"),
        "--fork", "os/manual.md=life/manual.md"
      )
      add.call("manual fork update failed: #{fork_apply_output.strip}") unless fork_apply_status.success?
      add.call("owner manual fork was not created") unless File.file?(File.join(fork_vault, "life", "manual.md"))
      expected_manual = Digest::SHA256.file("os/manual.md").hexdigest
      actual_manual = Digest::SHA256.file(File.join(fork_vault, "os", "manual.md")).hexdigest
      add.call("product manual was not restored") unless expected_manual == actual_manual
      me_path = File.join(fork_vault, "os", "me.md")
      File.write(me_path, File.read(me_path).sub("Manual fork: none by default.", "Manual fork: life/manual.md."))
      fork_validate, fork_validate_status = capture("ruby", "os/validate-starter-os.rb", chdir: fork_vault)
      add.call("manual fork routing did not validate: #{fork_validate.strip}") unless fork_validate_status.success?
    end
  else
    add.call("manual fork fixture could not be created: #{fork_create.strip}")
  end

  legacy_vault = File.join(tmp, "LEGACY-STARTER.os")
  legacy_create, legacy_create_status = capture("ruby", "setup/scripts/create-vault.rb", legacy_vault)
  if legacy_create_status.success?
    FileUtils.rm_f(File.join(legacy_vault, "os", "release.json"))
    legacy_root_bytes, legacy_root_status = capture(
      "git", "show", "4dd49ea:os/templates/root-AGENTS.txt"
    )
    add.call("recognized unversioned root fixture is unavailable from real history") unless legacy_root_status.success?
    File.binwrite(File.join(legacy_vault, "AGENTS.md"), legacy_root_bytes) if legacy_root_status.success?
    legacy_owner_path = File.join(legacy_vault, "life", "first-version-owner-note.md")
    File.write(legacy_owner_path, "unique owner work from the first version\n")
    legacy_owner_digest = Digest::SHA256.file(legacy_owner_path).hexdigest
    init_git.call(legacy_vault)
    legacy_plan = File.join(tmp, "legacy-update-plan.json")
    legacy_plan_output, legacy_plan_status = capture("ruby", "setup/scripts/update-vault.rb", "plan", legacy_vault, legacy_plan)
    add.call("legacy update plan failed: #{legacy_plan_output.strip}") unless legacy_plan_status.success?
    if legacy_plan_status.success?
      plan = JSON.parse(File.read(legacy_plan))
      conflicts = plan["entries"].select { |entry| entry["action"] == "conflict" }.map { |entry| entry["path"] }
      add.call("legacy update did not conservatively detect managed conflicts") if conflicts.empty?
      legacy_root_entry = plan["entries"].find { |entry| entry["path"] == "AGENTS.md" }
      add.call("recognized untouched unversioned root did not plan the ownership transfer") unless legacy_root_entry && legacy_root_entry["action"] == "adopt-owner-entry"
      command = [
        "ruby", "setup/scripts/update-vault.rb", "apply", legacy_vault, legacy_plan,
        "--root-backup", File.join(tmp, "legacy-root-backup")
      ]
      conflicts.each { |path| command.concat(["--replace", path]) }
      legacy_apply_output, legacy_apply_status = capture(*command)
      add.call("approved legacy update failed: #{legacy_apply_output.strip}") unless legacy_apply_status.success?
      if legacy_apply_status.success?
        add.call("legacy update changed unknown owner work") unless Digest::SHA256.file(legacy_owner_path).hexdigest == legacy_owner_digest
        legacy_release = JSON.parse(File.read(File.join(legacy_vault, "os", "release.json")))
        add.call("legacy update did not make the root entry owner-owned") unless legacy_release.dig("artifacts", "AGENTS.md", "ownership") == "owner-owned"
        legacy_root = File.read(File.join(legacy_vault, "AGENTS.md"))
        add.call("legacy update did not name the private root entry") unless legacy_root.include?("# LEGACY-STARTER.os agent entry")
        legacy_validate, legacy_validate_status = capture("ruby", "os/validate-starter-os.rb", chdir: legacy_vault)
        add.call("updated legacy vault did not validate: #{legacy_validate.strip}") unless legacy_validate_status.success?
      end
    end
  else
    add.call("legacy update fixture could not be created: #{legacy_create.strip}")
  end

  customized_legacy = File.join(tmp, "CUSTOM-LEGACY.os")
  customized_legacy_create, customized_legacy_create_status = capture("ruby", "setup/scripts/create-vault.rb", customized_legacy)
  if customized_legacy_create_status.success?
    FileUtils.rm_f(File.join(customized_legacy, "os", "release.json"))
    customized_legacy_root_seed, customized_legacy_root_seed_status = capture(
      "git", "show", "4dd49ea:os/templates/root-AGENTS.txt"
    )
    add.call("customized unversioned root fixture is unavailable from real history") unless customized_legacy_root_seed_status.success?
    customized_legacy_root = "#{customized_legacy_root_seed}\nOwner rule: keep this sentence exactly.\n"
    customized_legacy_root_path = File.join(customized_legacy, "AGENTS.md")
    File.write(customized_legacy_root_path, customized_legacy_root)
    customized_legacy_root_digest = Digest::SHA256.file(customized_legacy_root_path).hexdigest
    init_git.call(customized_legacy)
    customized_legacy_plan = File.join(tmp, "customized-legacy-plan.json")
    customized_legacy_plan_output, customized_legacy_plan_status = capture(
      "ruby", "setup/scripts/update-vault.rb", "plan", customized_legacy, customized_legacy_plan
    )
    add.call("customized unversioned update plan failed: #{customized_legacy_plan_output.strip}") unless customized_legacy_plan_status.success?
    if customized_legacy_plan_status.success?
      plan = JSON.parse(File.read(customized_legacy_plan))
      root_entry = plan["entries"].find { |entry| entry["path"] == "AGENTS.md" }
      add.call("customized unversioned root entry was not preserved") unless root_entry && root_entry["action"] == "preserve"
      conflicts = plan["entries"].select { |entry| entry["action"] == "conflict" }.map { |entry| entry["path"] }
      command = [
        "ruby", "setup/scripts/update-vault.rb", "apply", customized_legacy, customized_legacy_plan,
        "--root-backup", File.join(tmp, "customized-legacy-root-backup")
      ]
      conflicts.each { |path| command.concat(["--replace", path]) }
      customized_legacy_apply_output, customized_legacy_apply_status = capture(*command)
      add.call("customized unversioned update failed: #{customized_legacy_apply_output.strip}") unless customized_legacy_apply_status.success?
      if customized_legacy_apply_status.success?
        add.call("customized unversioned root entry changed") unless Digest::SHA256.file(customized_legacy_root_path).hexdigest == customized_legacy_root_digest
        customized_legacy_validate, customized_legacy_validate_status = capture("ruby", "os/validate-starter-os.rb", chdir: customized_legacy)
        add.call("customized unversioned update did not validate: #{customized_legacy_validate.strip}") unless customized_legacy_validate_status.success?
        add.call("customized unversioned root did not produce a reconciliation notice") unless customized_legacy_validate.include?("NOTICE preserved owner root AGENTS.md")
      end
    end
  else
    add.call("customized unversioned fixture could not be created: #{customized_legacy_create.strip}")
  end

  claude_fork_vault = File.join(tmp, "CLAUDE-FORK.os")
  claude_fork_create, claude_fork_create_status = capture("ruby", "setup/scripts/create-vault.rb", claude_fork_vault)
  if claude_fork_create_status.success?
    init_git.call(claude_fork_vault)
    File.open(File.join(claude_fork_vault, "CLAUDE.md"), "a") { |file| file.write("\nOwner Claude rule.\n") }
    claude_fork_plan = File.join(tmp, "claude-fork-plan.json")
    claude_fork_plan_output, claude_fork_plan_status = capture(
      "ruby", "setup/scripts/update-vault.rb", "plan", claude_fork_vault, claude_fork_plan
    )
    add.call("Claude adapter conflict plan failed: #{claude_fork_plan_output.strip}") unless claude_fork_plan_status.success?
    if claude_fork_plan_status.success?
      claude_entry = JSON.parse(File.read(claude_fork_plan))["entries"].find { |entry| entry["path"] == "CLAUDE.md" }
      add.call("modified root Claude adapter was not detected as a conflict") unless claude_entry && claude_entry["action"] == "conflict"
      claude_keep_output, claude_keep_status = capture(
        "ruby", "setup/scripts/update-vault.rb", "apply", claude_fork_vault, claude_fork_plan,
        "--root-backup", File.join(tmp, "claude-keep-root-backup"), "--keep", "CLAUDE.md"
      )
      if claude_keep_status.success? || !claude_keep_output.include?("use --fork CLAUDE.md=life/claude-entry.md")
        add.call("updater allowed an in-place root Claude fork that cannot validate")
      end
    end
  else
    add.call("Claude adapter fork fixture could not be created: #{claude_fork_create.strip}")
  end

  interrupted_vault = File.join(tmp, "INTERRUPTED-UPDATE.os")
  interrupted_version = build_historical_vault.call("v2.1.0", interrupted_vault)
  if interrupted_version == "2.1.0"
    File.open(File.join(interrupted_vault, "os", "AGENTS.md"), "a") { |file| file.write("\nOwner change selected for replacement in the failure test.\n") }
    File.open(File.join(interrupted_vault, "os", "manual.md"), "a") { |file| file.write("\nOwner manual text selected for a fork in the failure test.\n") }
    init_git.call(interrupted_vault)
    ignored_owner_path = File.join(interrupted_vault, "life", ".DS_Store")
    File.write(ignored_owner_path, "ignored owner file must survive restoration\n")
    external_owner_path = File.join(tmp, "external-owner-context.md")
    File.write(external_owner_path, "external owner context must stay unchanged\n")
    external_owner_digest = Digest::SHA256.file(external_owner_path).hexdigest
    interrupted_before = tree_digests(Pathname.new(interrupted_vault))

    interrupted_plan_path = File.join(tmp, "interrupted-update-plan.json")
    interrupted_plan_output, interrupted_plan_status = capture(
      "ruby", "setup/scripts/update-vault.rb", "plan", interrupted_vault, interrupted_plan_path
    )
    add.call("interrupted-update plan failed: #{interrupted_plan_output.strip}") unless interrupted_plan_status.success?
    if interrupted_plan_status.success?
      interrupted_root_backup = File.join(tmp, "interrupted-root-backup")
      failure_injector = File.join(tmp, "inject-update-write-failure.rb")
      File.write(failure_injector, <<~'RUBY')
        require ENV.fetch("STARTER_OS_TEST_SUPPORT")
        module FailUpdateWrite
          def atomic_write(root, raw, bytes, **options)
            result = super
            if root.to_s == File.realpath(ENV.fetch("STARTER_OS_TEST_TARGET_ROOT"))
              @test_count = @test_count.to_i + 1
              raise IOError, "injected validation failure after #{@test_count} target writes" if @test_count == Integer(ENV.fetch("STARTER_OS_TEST_FAIL_AFTER_WRITES"))
            end
            result
          end
        end
        UpdateSupport.singleton_class.prepend(FailUpdateWrite)
      RUBY
      interrupted_output, interrupted_status = capture(
        {
          "RUBYOPT" => "-r#{failure_injector}",
          "STARTER_OS_TEST_TARGET_ROOT" => interrupted_vault,
          "STARTER_OS_TEST_SUPPORT" => ROOT.join("setup/scripts/update-support.rb").to_s,
          "STARTER_OS_TEST_FAIL_AFTER_WRITES" => "3"
        },
        "ruby", "setup/scripts/update-vault.rb", "apply", interrupted_vault, interrupted_plan_path,
        "--root-backup", interrupted_root_backup,
        "--replace", "os/AGENTS.md",
        "--fork", "os/manual.md=life/manual.md"
      )
      if interrupted_status.success? || !interrupted_output.include?("injected validation failure after 3 target writes")
        add.call("update failure injection did not stop after partial writes: #{interrupted_output.strip}")
      end
      add.call("failure injection did not leave a partial state to restore") if tree_digests(Pathname.new(interrupted_vault)) == interrupted_before

      receipt_path = File.join(interrupted_root_backup, "receipt.json")
      if !File.file?(receipt_path)
        add.call("partial update did not preserve a root backup receipt")
      else
        receipt = JSON.parse(File.read(receipt_path))
        add.call("receipt did not record fork destination") unless receipt.fetch("new_paths").include?("life/manual.md")
        preview, preview_status = capture("ruby", "setup/scripts/restore-vault.rb", "plan", interrupted_vault, interrupted_root_backup)
        add.call("restore preview failed: #{preview}") unless preview_status.success?
        restored, restored_status = capture("ruby", "setup/scripts/restore-vault.rb", "apply", interrupted_vault, interrupted_root_backup)
        add.call("transaction restore failed: #{restored}") unless restored_status.success?
      end

      add.call("partial update did not restore the complete prior file state") unless tree_digests(Pathname.new(interrupted_vault)) == interrupted_before
      add.call("partial update restoration lost ignored owner content") unless File.file?(ignored_owner_path)
      add.call("partial update restoration changed external owner content") unless Digest::SHA256.file(external_owner_path).hexdigest == external_owner_digest
      %w[os life].each do |name|
        status_output, status_status = capture("git", "-C", File.join(interrupted_vault, name), "status", "--porcelain")
        add.call("partial update restoration left #{name}/ unreadable") unless status_status.success?
        add.call("partial update restoration left #{name}/ dirty: #{status_output.strip}") unless status_output.empty?
      end
    end
  else
    add.call("interrupted-update fixture could not be rebuilt from v2.1.0")
  end

  unrelated = File.join(tmp, "OTHER-REPOSITORY.os")
  FileUtils.mkdir_p(File.join(unrelated, "notes"))
  File.write(File.join(unrelated, "notes", "owner-context.md"), "old owner context stays here\n")
  init_repository.call(unrelated)
  unrelated_before = tree_digests(Pathname.new(unrelated))
  unrelated_git_before = git_state.call(unrelated)

  unrelated_output, unrelated_status = capture("ruby", "setup/scripts/create-vault.rb", unrelated)
  if unrelated_status.success? || !unrelated_output.include?("not empty")
    add.call("clean installer did not refuse an unrelated non-empty repository")
  end
  add.call("clean installer changed an unrelated repository") unless unrelated_before == tree_digests(Pathname.new(unrelated))
  add.call("clean installer changed unrelated Git history or configuration") unless unrelated_git_before == git_state.call(unrelated)

  FileUtils.mkdir_p(File.join(unrelated, "os"))
  FileUtils.mkdir_p(File.join(unrelated, "life"))
  unrelated_plan = File.join(tmp, "unrelated-update-plan.json")
  unrelated_update_output, unrelated_update_status = capture(
    "ruby", "setup/scripts/update-vault.rb", "plan", unrelated, unrelated_plan
  )
  if unrelated_update_status.success? || !unrelated_update_output.include?("not a recognized unversioned Starter.OS")
    add.call("updater accepted an unrelated repository as unversioned Starter.OS")
  end
  add.call("rejected update changed unrelated Git history or configuration") unless unrelated_git_before == git_state.call(unrelated)

  separate_vault = File.join(tmp, "SEPARATE.os")
  separate_output, separate_status = capture("ruby", "setup/scripts/create-vault.rb", separate_vault)
  add.call("separate install beside an unrelated repository failed: #{separate_output.strip}") unless separate_status.success?
  add.call("separate install changed an unrelated repository") unless unrelated_before == tree_digests(Pathname.new(unrelated))
  if separate_status.success?
    separate_root = File.read(File.join(separate_vault, "AGENTS.md"))
    add.call("separate install did not create the owner's named root entry") unless separate_root.include?("# SEPARATE.os agent entry")
  end
end

contract_output, contract_status = capture("ruby", "setup/scripts/test-update-contract.rb")
add.call("3.1 update contract tests failed:\n#{contract_output}") unless contract_status.success?
puts contract_output if contract_status.success?

source_after = tree_digests(ROOT)
add.call("validation modified the public source checkout") unless source_before == source_after

if errors.empty?
  puts "PASS Starter.OS #{TARGET_VERSION}: link-only routing, two guided paths, named owner entry, historical and customized root ownership handling, separate old-repository protection, unrecognized legacy refusal, external root backup, fork-aware interrupted-update restoration, local Git recovery gates, hosted-backup reporting, business Git commits, skill audit, protected manual and adapters, licenses, release manifest, clean install, history-backed 2.1 and 2.0 updates, recognized unversioned update, and privacy checks"
  exit 0
end

puts "FAIL Starter.OS #{TARGET_VERSION}: #{errors.length} issue#{errors.length == 1 ? '' : 's'}"
errors.each { |message| puts "- #{message}" }
exit 1
