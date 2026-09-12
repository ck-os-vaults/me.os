#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require_relative "update-support"

class UpdateContractTest < Minitest::Test
  SOURCE = Pathname.new(File.expand_path("../..", __dir__)).realpath
  HISTORY = "01f60e03b4ad22b4f9135051df57d73f8a7701f4"
  HISTORY_31 = "efc04180e09726dd4c6f7d47c8b98d972ef0f74d"
  VERSION = "3.2.0"

  def command(*args, cwd: SOURCE, env: {})
    output, status = Open3.capture2e(env, *args.map(&:to_s), chdir: cwd.to_s)
    [output, status.success?]
  end

  def success(*args, **options)
    output, ok = command(*args, **options)
    assert ok, output
    output
  end

  def refusal(*args, **options)
    before = @vault.directory? ? UpdateSupport.inventory(@vault) : nil
    output, ok = command(*args, **options)
    refute ok, output
    assert_equal before, UpdateSupport.inventory(@vault) if before
    output
  end

  def setup
    @tmp = Pathname.new(Dir.mktmpdir("starter-contract-")).realpath
    @vault = @tmp.join("OWNER.os")
    @sequence = 0
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def commit(folder)
    success("git", "-C", folder, "add", "-A")
    success("git", "-C", folder, "-c", "user.name=Starter test", "-c", "user.email=starter-test@example.invalid", "commit", "--allow-empty", "-qm", "fixture checkpoint")
  end

  def protect
    %w[os life].each do |name|
      success("git", "init", "-q", @vault.join(name))
      commit(@vault.join(name))
    end
  end

  def install
    success("ruby", SOURCE.join("setup/scripts/create-vault.rb"), @vault, "--allow-unreleased")
  end

  def original_install(ref, label)
    source = @tmp.join("original-#{label}")
    source.mkpath
    archive = @tmp.join("original-#{label}.tar")
    success("git", "archive", "--format=tar", "--output", archive, ref)
    success("tar", "-xf", archive, "-C", source)
    success("ruby", source.join("scripts/create-vault.rb"), @vault)
  end

  def historical(ref = HISTORY)
    # Build exactly the distributed 3.0 bytes, including its rendered root.
    manifest_text, ok = command("git", "show", "#{ref}:setup/release-manifest.json")
    manifest_text = success("git", "show", "#{ref}:release-manifest.json") unless ok
    manifest = JSON.parse(manifest_text)
    assert_includes %w[2.0.0 2.1.0 3.0.0 3.1.0], manifest.fetch("version")
    @vault.mkpath
    manifest.fetch("directories").each { |name| @vault.join(name).mkpath }
    records = {}
    manifest.fetch("artifacts").each do |artifact|
      bytes = success("git", "show", "#{ref}:#{artifact.fetch('source')}")
      assert_equal artifact.fetch("sha256"), Digest::SHA256.hexdigest(bytes)
      bytes = bytes.gsub("{{SYSTEM_NAME}}", @vault.basename.to_s) if artifact["render"]
      target = @vault.join(artifact.fetch("path"))
      target.dirname.mkpath
      File.binwrite(target, bytes)
      records[artifact.fetch("path")] = {
        "ownership" => artifact.fetch("ownership"), "sha256" => Digest::SHA256.hexdigest(bytes),
        "upstream_sha256" => artifact.fetch("sha256"), "source_version" => manifest.fetch("version")
      }
    end
    @vault.join("os/release.json").write(JSON.pretty_generate({
      "format" => 1, "product" => "Starter.OS", "version" => manifest.fetch("version"),
      "installed_at" => "2026-09-03T00:00:00Z", "manifest_sha256" => Digest::SHA256.hexdigest(manifest_text), "artifacts" => records
    }))
  end

  def plan(*selection, source: SOURCE)
    @sequence += 1
    path = @tmp.join("plan-#{@sequence}.json")
    before = UpdateSupport.inventory(@vault)
    success("ruby", source.join("setup/scripts/update-vault.rb"), "plan", @vault, path, *selection)
    assert_equal before, UpdateSupport.inventory(@vault), "review mutated the installed system"
    path
  end

  def apply(path, *choices, source: SOURCE, env: {})
    @sequence += 1
    backup = @tmp.join("backup-#{@sequence}")
    success("ruby", source.join("setup/scripts/update-vault.rb"), "apply", @vault, path, "--root-backup", backup, "--allow-unreleased", *choices, env: env)
    backup
  end

  def copied_source(name)
    copy = @tmp.join(name)
    manifest = JSON.parse(SOURCE.join("setup/release-manifest.json").read)
    paths = manifest.fetch("distribution_files").map { |row| row.fetch("path") } + ["setup/release-manifest.json"]
    paths.each do |raw|
      destination = copy.join(raw)
      destination.dirname.mkpath
      FileUtils.cp(SOURCE.join(raw), destination)
    end
    [copy, manifest]
  end

  def record
    JSON.parse(@vault.join("os/release.json").read)
  end

  def validate(*options)
    success("ruby", "os/validate-starter-os.rb", *options, cwd: @vault)
  end

  def test_installer_handoff_honors_protection_before_personalization_and_deferral
    output = install
    assert_match(/Next: establish and verify .* before substantial personalization/, output)
    assert_includes output, "If Git was declined or deferred, honor that choice"
    assert_includes output, "do not initialize Git to pass a check"
    assert_includes output, "add --foundation for explicit Git decline/deferral"
    assert_includes validate("--foundation"), "not proof of fully protected setup"
    protect
    validate
  end

  def assert_original_version_update_and_restore(ref, version)
    original_install(ref, version)
    original_record = record
    assert_equal 1, original_record.fetch("format")
    assert_equal "Starter.OS", original_record.fetch("product")
    assert_equal version, original_record.fetch("version")
    custom = "os/skills/eod-wrap.md"
    @vault.join(custom).open("a") { |file| file.puts "Owner-specific method must survive." }
    owner_bytes = @vault.join(custom).binread
    @vault.join("life/owner-note.md").write("Existing owner work.")
    protect
    before = UpdateSupport.inventory(@vault)
    backup = apply(plan, "--keep", custom)
    assert_equal owner_bytes, @vault.join(custom).binread
    assert_equal VERSION, record.fetch("version")
    assert_equal version, record.fetch("installed_source").fetch("version")
    assert_equal original_record.fetch("installed_at"), record.fetch("installed_at")
    validate
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("unsupported-partial.json"), "--only", "news-report")
  end

  def test_original_20_installer_record_full_update_and_restore
    assert_original_version_update_and_restore("bb7d3c744348c933b03181a7dffa0b6a8c8701ca", "2.0.0")
  end

  def test_original_21_installer_record_full_update_and_restore
    assert_original_version_update_and_restore("dd03a11567d4aca1c6493656e0c0f4617f18f03b", "2.1.0")
  end

  def test_original_unversioned_install_mixed_stock_and_custom_plan_restores_exactly
    original_install("4dd49ea", "unversioned")
    refute @vault.join("os/release.json").exist?
    # These baseline bytes come from the original installer at the immutable
    # historical source above; they are not inferred from the candidate template.
    stock = UpdateSupport.inventory(@vault)
    custom = "os/skills/eod-wrap.md"
    @vault.join(custom).open("a") { |file| file.puts "Owner-specific method must survive." }
    owner_bytes = @vault.join(custom).binread
    @vault.join("life/owner-note.md").write("Existing unversioned owner work.")
    protect
    before = UpdateSupport.inventory(@vault)
    proposal = plan
    entries = JSON.parse(proposal.read).fetch("entries")
    stock_path = "os/AGENTS.md"
    assert_equal "conflict", entries.find { |row| row["path"] == stock_path }.fetch("action")
    # One reviewed plan groups verified stock replacements and an explicit owner
    # fork. Unknown/mismatched bytes never enter the replacement group.
    choices = entries.select { |row| row["action"] == "conflict" }.flat_map do |row|
      path = row.fetch("path")
      if path == custom
        ["--keep", path]
      else
        assert_equal stock.fetch(path), UpdateSupport.state(@vault.join(path)), "unreviewed legacy replacement: #{path}"
        ["--replace", path]
      end
    end
    backup = apply(proposal, *choices)
    assert_equal owner_bytes, @vault.join(custom).binread
    assert_equal "owner-owned", record.fetch("artifacts").fetch(custom).fetch("ownership")
    assert record.fetch("artifacts").fetch(custom).fetch("customized")
    assert_equal SOURCE.join(stock_path).binread, @vault.join(stock_path).binread
    validate
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_candidate_is_not_silently_installed_or_applied
    source, manifest = copied_source("unreleased-build")
    manifest["status"] = "unreleased"
    manifest["released"] = nil
    source.join("setup/release-manifest.json").write(JSON.pretty_generate(manifest) + "\n")
    refusal("ruby", source.join("setup/scripts/create-vault.rb"), @vault)
    refute @vault.exist?
    historical
    protect
    refusal("ruby", source.join("setup/scripts/update-vault.rb"), "apply", @vault, plan(source: source), "--root-backup", @tmp.join("unapproved"))
    refute @tmp.join("unapproved").exist?
  end

  def test_current_release_creates_without_candidate_override
    manifest = JSON.parse(SOURCE.join("setup/release-manifest.json").read)
    assert_equal "released", manifest.fetch("status")
    assert_equal "2026-09-12", manifest.fetch("released")
    success("ruby", SOURCE.join("setup/scripts/create-vault.rb"), @vault)
    assert_equal VERSION, record.fetch("version")
    validate("--foundation")
  end

  def test_current_release_updates_without_candidate_override
    historical
    protect
    before = UpdateSupport.inventory(@vault)
    backup = @tmp.join("released-backup")
    success("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, plan, "--root-backup", backup)
    assert_equal VERSION, record.fetch("version")
    validate
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_new_foundation_can_explicitly_defer_git
    install
    refusal("ruby", "os/validate-starter-os.rb", cwd: @vault)
    assert_includes validate("--foundation"), "not proof of fully protected setup"
    refute @vault.join("os/.git").exist?
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, plan, "--allow-unreleased", "--root-backup", @tmp.join("not-protected"))
  end

  def test_foundation_without_git_executable_reports_deferral
    install
    empty_path = @tmp.join("no-tools")
    empty_path.mkpath
    File.symlink("/usr/bin/uname", empty_path.join("uname")) if File.executable?("/usr/bin/uname")
    output = success(RbConfig.ruby, "os/validate-starter-os.rb", "--foundation", cwd: @vault, env: { "PATH" => empty_path.to_s })
    assert_includes output, "Git is unavailable; owner-deferred protection"
    assert_includes refusal(RbConfig.ruby, "os/validate-starter-os.rb", cwd: @vault, env: { "PATH" => empty_path.to_s }), "Git executable is unavailable"
  end

  def test_nested_git_boundaries_refuse_forks_and_later_repository_creation
    historical
    @vault.join("os/manual.md").open("a") { |file| file.puts "Owner text to preserve." }
    @vault.join("life/.gitignore").open("a") { |file| file.puts "embedded/" }
    embedded = @vault.join("life/embedded")
    embedded.mkpath
    embedded.join("keep.md").write("Nested owner work.")
    protect
    proposal = plan
    choices = ["--keep", "life/.gitignore", "--fork", "os/manual.md=life/embedded/manual.md"]
    success("git", "init", "-q", embedded)
    commit(embedded)
    assert_includes refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--allow-unreleased", "--root-backup", @tmp.join("nested-refusal"), *choices), "repository boundary"
    FileUtils.remove_entry(embedded.join(".git"))
    backup = apply(proposal, *choices)
    success("git", "init", "-q", embedded)
    commit(embedded)
    assert_includes refusal("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup), "repository boundary"
    assert embedded.join("manual.md").file?
  end

  def test_personalized_real_30_updates_and_restores_exactly
    historical
    @vault.join("AGENTS.md").open("a") { |file| file.puts "Owner requests on-demand planning only." }
    @vault.join("os/me.md").open("a") { |file| file.puts "Owner prefers concise answers and no morning questionnaire." }
    @vault.join("os/skills/personal-method.md").write("# Personal method\n\nOnly on explicit request.\n")
    @vault.join("os/owner-skills.md").write("# My methods\n\n| [[personal-method]] | optional portable | explicit request | no |\n")
    @vault.join("life/archive").mkpath
    @vault.join("life/archive/owner-note.md").write("Keep this meaningful owner history.\n")
    @vault.join(".codex").mkpath
    @vault.join(".codex/config.toml").write("# Owner config; never execute in validation\n")
    success("ruby", "os/scripts/add-project.rb", "actual-project", cwd: @vault)
    success("ruby", "os/scripts/add-business.rb", "actual-business", cwd: @vault)
    business = @vault.join("biz/actual-business")
    success("git", "init", "-q", business)
    commit(business)
    protect
    @vault.join("life/.DS_Store").write("Ignored local owner content\n")
    external = @tmp.join("external-context.md")
    external.write("External owner data\n")
    before = UpdateSupport.inventory(@vault)
    original_date = record.fetch("installed_at")
    original_manifest = record.fetch("manifest_sha256")
    backup = apply(plan)
    assert_equal VERSION, record.fetch("version")
    assert_equal original_date, record.fetch("installed_at")
    assert_equal({ "version" => "3.0.0", "manifest_sha256" => original_manifest }, record.fetch("installed_source"))
    %w[AGENTS.md os/me.md os/owner-skills.md os/skills/personal-method.md life/archive/owner-note.md life/.DS_Store .codex/config.toml].each do |path|
      assert_equal before.fetch(path), UpdateSupport.state(@vault.join(path)), path
    end
    validate
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "plan", @vault, backup)
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
    assert_equal "External owner data\n", external.read
  end

  def test_personal_skill_needs_no_product_registry_edit
    install
    product_registry = @vault.join("os/skill-map.md").binread
    @vault.join("os/skills/my-workflow.md").write("# My workflow\n\nRun when requested.\n")
    @vault.join("os/owner-skills.md").open("a") { |file| file.puts "| [[my-workflow]] | optional portable | owner request | no |" }
    protect
    validate
    assert_equal product_registry, @vault.join("os/skill-map.md").binread
    @vault.join("os/owner-skills.md").open("a") { |file| file.puts "| [[my-workflow]] | optional portable | duplicate | no |" }
    assert_includes refusal("ruby", "os/validate-starter-os.rb", cwd: @vault), "duplicate skill registration"
  end

  def test_generated_record_link_is_rejected_before_any_write
    historical
    metadata = @vault.join("os/release.json")
    external = @tmp.join("external-record.json")
    external.write(metadata.read)
    metadata.unlink
    metadata.make_symlink(external)
    original = external.binread
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("bad-plan.json"))
    assert_equal original, external.binread
    refute @tmp.join("bad-plan.json").exist?
  end

  def test_selective_adoption_preserves_declined_groups_and_base_version
    historical
    protect
    before = UpdateSupport.inventory(@vault)
    proposal = plan("--only", "news-report")
    parsed = JSON.parse(proposal.read)
    assert_equal %w[governance news-report validation], parsed.fetch("selected_groups")
    assert_equal "partial", parsed.fetch("adoption")
    backup = apply(proposal)
    assert_equal "3.0.0", record.fetch("version")
    assert_equal VERSION, record.fetch("adoption").fetch("offered_version")
    changed = JSON.parse(backup.join("receipt.json").read).fetch("writes").map { |row| row.fetch("path") }
    assert_empty changed - %w[os/AGENTS.md os/skills/news-report.md os/validate-starter-os.rb os/owner-skills.md os/release.json]
    before.each do |path, state|
      assert_equal state, UpdateSupport.state(@vault.join(path)) unless changed.include?(path)
    end
    validate
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("unknown-group.json"), "--only", "not-a-group")
  end

  def test_existing_fork_retains_baseline_and_can_rejoin
    historical
    path = "os/skills/eod-wrap.md"
    original = record.fetch("artifacts").fetch(path)
    @vault.join(path).open("a") { |file| file.puts "Owner-specific wrap behavior." }
    owner_bytes = @vault.join(path).binread
    protect
    apply(plan, "--keep", path)
    fork = record.fetch("artifacts").fetch(path)
    assert_equal original.fetch("upstream_sha256"), fork.fetch("fork_base").fetch("sha256")
    assert_equal "3.0.0", fork.fetch("fork_base").fetch("version")
    assert_equal owner_bytes, @vault.join(path).binread
    commit(@vault.join("os"))
    commit(@vault.join("life"))
    proposal = plan
    assert_equal "forked", JSON.parse(proposal.read).fetch("entries").find { |row| row["path"] == path }.fetch("action")
    apply(proposal, "--replace", path)
    assert_equal "owner-owned", record.fetch("artifacts").fetch(path).fetch("ownership")
    refute record.fetch("artifacts").fetch(path).fetch("customized")
    assert_equal SOURCE.join(path).binread, @vault.join(path).binread
    validate
  end

  def test_fork_across_another_release_keeps_original_identity_and_reports_new_upstream
    historical
    path = "os/skills/eod-wrap.md"
    @vault.join(path).open("a") { |file| file.puts "Owner-specific method." }
    owner_bytes = @vault.join(path).binread
    protect
    apply(plan, "--keep", path)
    original_base = record.fetch("artifacts").fetch(path).fetch("fork_base")
    %w[os life].each { |name| commit(@vault.join(name)) }
    source, manifest = copied_source("future-source")
    manifest["version"] = "3.3.0"
    manifest["supported_updates"] << "3.3.0"
    source.join(path).open("a") { |file| file.puts "Synthetic future release improvement." }
    digest = Digest::SHA256.file(source.join(path)).hexdigest
    manifest.fetch("artifacts").find { |row| row["path"] == path }["sha256"] = digest
    manifest.fetch("distribution_files").find { |row| row["path"] == path }["sha256"] = digest
    source.join("setup/release-manifest.json").write(JSON.pretty_generate(manifest))
    proposal = plan(source: source)
    assert JSON.parse(proposal.read).fetch("entries").find { |row| row["path"] == path }.fetch("upstream_changed")
    apply(proposal, "--keep", path, source: source)
    fork = record.fetch("artifacts").fetch(path)
    assert_equal original_base, fork.fetch("fork_base")
    assert_equal "3.3.0", fork.fetch("available_upstream").fetch("version")
    assert_equal owner_bytes, @vault.join(path).binread
    %w[os life].each { |name| commit(@vault.join(name)) }
    reviewed = plan(source: source)
    refute JSON.parse(reviewed.read).fetch("entries").find { |row| row["path"] == path }.fetch("upstream_changed")
    apply(reviewed, "--replace", path, source: source)
    assert_equal "owner-owned", record.fetch("artifacts").fetch(path).fetch("ownership")
    assert_equal source.join(path).binread, @vault.join(path).binread
    assert_equal "3.0.0", record.fetch("installed_source").fetch("version")
    validate
  end

  def test_dependencies_are_included_and_owner_takeover_is_rejected
    historical
    protect
    source, manifest = copied_source("dependency-source")
    manifest.fetch("update_groups").fetch("news-report")["requires"] = ["foundation"]
    source.join("setup/release-manifest.json").write(JSON.pretty_generate(manifest))
    proposal = plan("--only", "news-report", source: source)
    selection = JSON.parse(proposal.read)
    assert_equal %w[foundation governance news-report validation], selection.fetch("selected_groups")
    apply(proposal, source: source)
    validate
    manifest.fetch("artifacts").find { |row| row["path"] == "os/me.md" }["ownership"] = "managed"
    source.join("setup/release-manifest.json").write(JSON.pretty_generate(manifest))
    assert_includes refusal("ruby", source.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("takeover.json")), "attempts to take ownership"
  end

  def test_manual_fork_routing_is_in_the_recovery_transaction
    historical
    @vault.join("os/manual.md").open("a") { |file| file.puts "Owner explanation." }
    owner_manual = @vault.join("os/manual.md").binread
    protect
    before = UpdateSupport.inventory(@vault)
    backup = apply(plan, "--fork", "os/manual.md=life/manual.md")
    assert_equal owner_manual, @vault.join("life/manual.md").binread
    assert_includes @vault.join("os/me.md").read, "life/manual.md"
    validate
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_record_drift_after_review_refuses_apply
    historical
    protect
    proposal = plan
    value = record
    value["installed_at"] = "owner changed metadata after review"
    @vault.join("os/release.json").write(JSON.pretty_generate(value))
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--allow-unreleased", "--root-backup", @tmp.join("stale"))
    refute @tmp.join("stale").exist?
  end

  def test_real_update_requires_external_recovery_location
    historical
    protect
    proposal = plan
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--allow-unreleased")
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--allow-unreleased", "--root-backup", @vault.join("wrong-backup"))
    refute @vault.join("wrong-backup").exist?
  end

  def test_no_change_preserves_metadata_and_creates_no_transaction
    install
    protect
    before = UpdateSupport.inventory(@vault)
    backup = apply(plan)
    refute backup.exist?
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_older_partial_combinations_are_refused_without_mutation
    historical("bb7d3c744348c933b03181a7dffa0b6a8c8701ca")
    protect
    %w[foundation news-report].each do |group|
      assert_includes refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("#{group}.json"), "--only", group), "selected adoption is not validated"
    end
  end

  def test_forks_cannot_escape_transaction_repositories_or_overwrite_generated_record
    historical
    @vault.join("os/manual.md").open("a") { |file| file.puts "Owner text to preserve." }
    protect
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, plan, "--allow-unreleased", "--root-backup", @tmp.join("wrong-fork"), "--fork", "os/manual.md=biz/example/manual.md")
    @vault.join("os/release.json").unlink
    commit(@vault.join("os"))
    proposal = plan
    choices = JSON.parse(proposal.read).fetch("entries").select { |row| row["action"] == "conflict" && row["path"] != "os/manual.md" }.flat_map { |row| ["--replace", row.fetch("path")] }
    assert_includes refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--allow-unreleased", "--root-backup", @tmp.join("wrong-record"), "--fork", "os/manual.md=os/release.json", *choices), "generated release metadata"
  end

  def test_case_alias_forks_cannot_enter_git_or_break_recovery_paths
    historical
    @vault.join("os/manual.md").open("a") { |file| file.puts "Owner text to preserve." }
    protect
    proposal = plan
    git_before = Dir.glob(@vault.join("os/.git/**/*").to_s, File::FNM_DOTMATCH).select { |file| File.file?(file) }.to_h { |file| [file, Digest::SHA256.file(file).hexdigest] }
    %w[os/.GIT/owner-copy.md os/Skills/owner-copy.md life/Projects/owner-copy.md os/RELEASE.json].each_with_index do |destination, index|
      refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--allow-unreleased", "--root-backup", @tmp.join("case-#{index}"), "--fork", "os/manual.md=#{destination}")
      git_after = Dir.glob(@vault.join("os/.git/**/*").to_s, File::FNM_DOTMATCH).select { |file| File.file?(file) }.to_h { |file| [file, Digest::SHA256.file(file).hexdigest] }
      assert_equal git_before, git_after
    end
    assert_raises(RuntimeError) { UpdateSupport.safe(@vault, "os/.GIT/owner-copy.md") }
    assert_raises(RuntimeError) { UpdateSupport.safe(@vault, "os/Skills/owner-copy.md") }
  end

  def test_sigkill_crash_remnants_are_recorded_and_restorable
    historical
    protect
    before = UpdateSupport.inventory(@vault)
    injector = @tmp.join("kill-before-rename.rb")
    injector.write(<<~'RUBY')
      module KillDuringRename
        def rename(source, destination)
          if destination.to_s == File.join(File.realpath(ENV.fetch("KILL_TARGET")), "os/manual.md")
            Process.kill("KILL", Process.pid)
          end
          super
        end
      end
      File.singleton_class.prepend(KillDuringRename)
    RUBY
    backup = @tmp.join("killed-backup")
    output, ok = command("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, plan, "--allow-unreleased", "--root-backup", backup, env: { "RUBYOPT" => "-r#{injector}", "KILL_TARGET" => @vault.to_s })
    refute ok, output
    remnants = Dir.glob(@vault.join("os/.starter-write-*.tmp").to_s)
    assert_equal 1, remnants.length
    remnant = Pathname.new(remnants.first)
    staged = remnant.binread
    remnant.write("Later owner content must not be discarded.")
    refusal("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    File.binwrite(remnant, staged)
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_restore_refuses_later_owner_work_and_altered_backup
    historical
    protect
    backup = apply(plan)
    owner_file = @vault.join("life/later-note.md")
    owner_file.write("Do not discard this later work.\n")
    assert_includes refusal("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup), "later owner changes"
    owner_file.unlink
    modified = @vault.join("os/manual.md")
    original = modified.binread
    modified.open("a") { |file| file.puts "Later customization." }
    refusal("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    File.binwrite(modified, original)
    saved = backup.join("before/os/manual.md")
    saved.open("a") { |file| file.puts "Changed recovery bytes." }
    assert_includes refusal("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup), "altered recovery bytes"
  end

  def test_interrupted_transactions_restore_at_multiple_boundaries
    historical
    protect
    before = UpdateSupport.inventory(@vault)
    injector = @tmp.join("inject.rb")
    injector.write(<<~'RUBY')
      require ENV.fetch("TEST_SUPPORT")
      module InjectTransactionFailure
        def atomic_write(root, path, bytes, **options)
          target_write = root.to_s == File.realpath(ENV.fetch("TEST_TARGET"))
          if target_write
            @count = @count.to_i + 1
            fail_here = ENV["TEST_BOUNDARY"] == path || ENV["TEST_BOUNDARY"] == @count.to_s
            raise IOError, "test failure before write" if fail_here && ENV["TEST_PHASE"] == "before"
          end
          result = super
          raise IOError, "test failure after write" if target_write && fail_here && ENV["TEST_PHASE"] == "after"
          result
        end
      end
      UpdateSupport.singleton_class.prepend(InjectTransactionFailure)
    RUBY
    [["1", "before"], ["3", "after"], ["os/release.json", "before"], ["os/release.json", "after"]].each_with_index do |(boundary, phase), i|
      backup = @tmp.join("interrupted-#{i}")
      output, ok = command("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, plan, "--allow-unreleased", "--root-backup", backup, env: {
        "RUBYOPT" => "-r#{injector}", "TEST_SUPPORT" => SOURCE.join("setup/scripts/update-support.rb").to_s,
        "TEST_TARGET" => @vault.to_s, "TEST_BOUNDARY" => boundary, "TEST_PHASE" => phase
      })
      refute ok, output
      assert_includes output, "test failure"
      success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "plan", @vault, backup)
      success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
      assert_equal before, UpdateSupport.inventory(@vault)
    end
  end

  def test_personalized_31_full_update_preserves_content_without_fork_registration
    historical(HISTORY_31)
    paths = %w[AGENTS.md CLAUDE.md os/AGENTS.md os/manual.md os/skill-map.md os/skills/eod-wrap.md]
    paths.each { |path| @vault.join(path).open("a") { |file| file.puts "Owner instruction: work on demand and preserve approved terminology." } }
    @vault.join("os/manual.md").write("# My working guide\n\nUse [our rules](AGENTS.md).\n")
    legacy = record
    legacy["artifacts"]["os/skills/eod-wrap.md"]["ownership"] = "forked"
    legacy["artifacts"]["os/skills/eod-wrap.md"]["fork_base"] = { "version" => "3.0.0", "sha256" => "a" * 64 }
    @vault.join("os/release.json").write(JSON.pretty_generate(legacy))
    protect
    before = UpdateSupport.inventory(@vault)
    candidate = @tmp.join("reviewed-rules.md")
    candidate.write(@vault.join("os/AGENTS.md").read + "\n## Current owner maintenance authority\n\nLegacy Starter.OS-imposed fork and product-update restrictions no longer apply to instructions, manuals, or registries. Maintain these within owner authority; preserve independently chosen owner protections.\n")
    notes = @tmp.join("governance-preservation.md")
    notes.write("Retain every existing owner instruction and terminology verbatim. Only legacy product-imposed edit/fork restrictions are superseded by the final owner-maintenance authority section; independent owner protections are unchanged.\n")
    backup = apply(plan("--adapt", "os/AGENTS.md=#{candidate}", "--review", notes))
    (paths - ["os/AGENTS.md"]).each { |path| assert_equal before.fetch(path), UpdateSupport.state(@vault.join(path)) }
    assert_equal candidate.binread, @vault.join("os/AGENTS.md").binread
    assert_equal 2, record.fetch("format")
    assert_equal "3.1.0", record.fetch("version")
    assert_equal "adapted", record.dig("adoption", "kind")
    assert_equal legacy.fetch("installed_at"), record.fetch("installed_at")
    assert_equal legacy.dig("artifacts", "os/skills/eod-wrap.md", "fork_base"), record.dig("artifacts", "os/skills/eod-wrap.md", "fork_base")
    validate
    refute @vault.join("life/manual.md").exist?
    %w[os life].each { |name| commit(@vault.join(name)) }
    current = UpdateSupport.inventory(@vault)
    refute apply(plan("--adapt", "os/AGENTS.md=#{candidate}", "--review", notes)).exist?
    assert_equal current, UpdateSupport.inventory(@vault)
    # Later commits are protected; do not rewind them to make restoration pass.
    refusal("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
  end

  def adaptation_inputs(path = "os/manual.md")
    candidate = @tmp.join("candidate.md")
    candidate.write(@vault.join(path).read + "\nReviewed improvement with existing owner instructions retained.\n")
    notes = @tmp.join("preservation.md")
    notes.write("Existing instructions retained verbatim. No removals or consolidated requirements. Candidate adds only the approved improvement; manual and root routes remain in place. Verify local health and the exact inventory, then review external protection separately.\n")
    [candidate, notes]
  end

  def test_31_selected_exact_adaptations_include_root_and_restore
    historical(HISTORY_31)
    @vault.join("os/manual.md").write("# My manual\n\nOriginal owner instructions.\n")
    @vault.join("os/me.md").open("a") { |file| file.puts "Manual route: os/manual.md." }
    protect
    before = UpdateSupport.inventory(@vault)
    candidate, notes = adaptation_inputs
    root = @tmp.join("root.md")
    root.write(@vault.join("AGENTS.md").read + "\nOwner-approved entry clarification.\n")
    proposal = plan("--only", "foundation", "--adapt", "os/manual.md=#{candidate}", "--adapt", "AGENTS.md=#{root}", "--review", notes)
    assert_equal "adapted", JSON.parse(proposal.read).fetch("adoption")
    backup = apply(proposal)
    assert_equal candidate.binread, @vault.join("os/manual.md").binread
    assert_equal root.binread, @vault.join("AGENTS.md").binread
    assert_equal notes.binread, backup.join("preservation-notes.md").binread
    assert_equal "3.1.0", record.fetch("version")
    assert_equal 2, record.fetch("format")
    assert_equal %w[AGENTS.md os/manual.md], record.fetch("adoption").fetch("adapted_paths")
    assert_equal before.fetch("os/skills/news-report.md"), UpdateSupport.state(@vault.join("os/skills/news-report.md"))
    validate
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_adaptation_inputs_notes_source_and_plan_tampering_refuse_before_writes
    historical(HISTORY_31)
    protect
    candidate, notes = adaptation_inputs
    original = candidate.binread
    notes_original = notes.binread
    proposal = plan("--only", "foundation", "--adapt", "os/manual.md=#{candidate}", "--review", notes)
    candidate.open("a") { |file| file.puts "Unreviewed candidate edit." }
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--root-backup", @tmp.join("changed-candidate"))
    candidate.binwrite(original)
    notes.open("a") { |file| file.puts "Unreviewed removal." }
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--root-backup", @tmp.join("changed-notes"))
    notes.binwrite(notes_original)
    value = JSON.parse(proposal.read)
    value["adaptations"]["os/manual.md"]["sha256"] = "f" * 64
    proposal.write(JSON.pretty_generate(value))
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--root-backup", @tmp.join("changed-plan"))
    source, _manifest = copied_source("changed-source")
    source_plan = plan("--only", "foundation", "--adapt", "os/manual.md=#{candidate}", "--review", notes, source: source)
    source.join("os/AGENTS.md").open("a") { |file| file.puts "Unreviewed source." }
    refusal("ruby", source.join("setup/scripts/update-vault.rb"), "apply", @vault, source_plan, "--root-backup", @tmp.join("changed-source-backup"))
    %w[changed-candidate changed-notes changed-plan changed-source-backup].each { |name| refute @tmp.join(name).exist? }
  end

  def test_adaptation_scope_guards_and_unknown_owner_file_transaction
    historical(HISTORY_31)
    nested = @vault.join("life/nested")
    nested.mkpath
    nested.join("note.md").write("Nested work")
    @vault.join("life/.gitignore").open("a") { |file| file.puts "nested/" }
    protect
    success("git", "init", "-q", nested)
    commit(nested)
    candidate, notes = adaptation_inputs
    %w[os/release.json os/RELEASE.json os/.git/config os/.codex/config.toml os/Skills/custom.md life/nested/note.md biz/shop/AGENTS.md ../escape.md].each_with_index do |path, i|
      refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("refused-#{i}.json"), "--adapt", "#{path}=#{candidate}", "--review", notes)
    end
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("unselected.json"), "--only", "news-report", "--adapt", "os/manual.md=#{candidate}", "--review", notes)
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("no-notes.json"), "--adapt", "os/manual.md=#{candidate}")
    linked = @vault.join("life/linked.md")
    linked.make_symlink(candidate)
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("linked.json"), "--adapt", "life/linked.md=#{candidate}", "--review", notes)
    linked.unlink
    before = UpdateSupport.inventory(@vault)
    backup = apply(plan("--only", "news-report", "--adapt", "life/owner-guide.md=#{candidate}", "--review", notes))
    assert_equal candidate.binread, @vault.join("life/owner-guide.md").binread
    assert_equal "owner-owned", record.dig("artifacts", "life/owner-guide.md", "ownership")
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_repeated_selected_and_adapted_runs_do_not_change_dates_or_create_backups
    historical(HISTORY_31)
    protect
    apply(plan("--only", "news-report"))
    %w[os life].each { |name| commit(@vault.join(name)) }
    before = UpdateSupport.inventory(@vault)
    refute apply(plan("--only", "news-report")).exist?
    assert_equal before, UpdateSupport.inventory(@vault)
    candidate, notes = adaptation_inputs
    args = ["--only", "foundation", "--adapt", "os/manual.md=#{candidate}", "--review", notes]
    apply(plan(*args))
    %w[os life].each { |name| commit(@vault.join(name)) }
    before = UpdateSupport.inventory(@vault)
    refute apply(plan(*args)).exist?
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_old_31_updater_refuses_full_partial_and_adapted_records
    source = @tmp.join("old-source")
    source.mkpath
    archive = @tmp.join("old-source.tar")
    success("git", "archive", "--format=tar", "--output", archive, HISTORY_31)
    success("tar", "-xf", archive, "-C", source)
    [[], ["--only", "news-report"], :adapted].each do |selection|
      historical(HISTORY_31)
      protect
      old_plan = plan(source: source)
      if selection == :adapted
        candidate, notes = adaptation_inputs
        selection = ["--only", "foundation", "--adapt", "os/manual.md=#{candidate}", "--review", notes]
      end
      backup = apply(plan(*selection))
      assert_equal 2, record.fetch("format")
      assert_includes refusal("ruby", source.join("setup/scripts/update-vault.rb"), "plan", @vault, @tmp.join("old-refusal-#{@sequence}.json")), "unsupported installed release record"
      refusal("ruby", source.join("setup/scripts/update-vault.rb"), "apply", @vault, old_plan, "--root-backup", @tmp.join("old-backup-#{@sequence}"))
      success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
      FileUtils.remove_entry(@vault)
    end
  end

  def test_operational_health_checks_production_recovery_table_and_business_links
    install
    success("ruby", "os/scripts/add-business.rb", "sample-team", cwd: @vault)
    business = @vault.join("biz/sample-team")
    success("git", "init", "-q", business)
    commit(business)
    project = @vault.join("life/projects/client-work")
    project.mkpath
    project.join("client-work.md").write("# Client work\n\nAn independently protected real project.\n")
    @vault.join("life/.gitignore").open("a") { |file| file.puts "projects/client-work/" }
    success("git", "init", "-q", project)
    commit(project)
    recovery = @vault.join("os/recovery.md")
    recovery.write(recovery.read.sub("|---|---|---|---|---|---|---|---|", "|---|---|---|---|---|---|---|---|\n| Client work | `life/projects/client-work` | private provider | unverified | none | none | configured but unverified | 2026-09-12 |"))
    @vault.join("os/manual.md").write("# Owner's working manual\n\nDifferent wording, same valid system.\n")
    @vault.join("CLAUDE.md").write("# Owner adapter\n\nRead AGENTS.md. Keep the owner's preferred language.\n")
    protect
    validate
    project_git = project.join(".git")
    moved = @tmp.join("project-git")
    FileUtils.mv(project_git, moved)
    assert_includes refusal("ruby", "os/validate-starter-os.rb", cwd: @vault), "not an independent Git repository"
    FileUtils.mv(moved, project_git)
    business.join("knowledge-map.md").open("a") { |file| file.puts "\n[Missing work](missing-project.md)\n" }
    assert_includes refusal("ruby", "os/validate-starter-os.rb", cwd: @vault), "broken local link: biz/sample-team/knowledge-map.md"
  end

  def test_broken_owner_startup_route_fails_but_custom_wording_is_valid
    install
    protect
    @vault.join("AGENTS.md").write("# My system\n\nRead os/AGENTS.md, then os/me.md. Follow nearest AGENTS.md in life and biz.\n")
    validate
    @vault.join("AGENTS.md").write("# My system\n\nRead missing-rules.md.\n")
    assert_includes refusal("ruby", "os/validate-starter-os.rb", cwd: @vault), "does not route to os/AGENTS.md"
  end

  def test_percent_encoded_local_links_are_valid_owner_content
    install
    @vault.join("life/My Working Note.md").write("# Working note\n")
    @vault.join("life/knowledge-map.md").open("a") { |file| file.puts "[Working note](My%20Working%20Note.md)\n" }
    protect
    validate
    @vault.join("life/My Working Note.md").unlink
    assert_includes refusal("ruby", "os/validate-starter-os.rb", cwd: @vault), "broken local link: life/knowledge-map.md"
  end

  def test_manual_fork_cannot_overwrite_exact_owner_context_adaptation
    historical(HISTORY_31)
    @vault.join("os/manual.md").open("a") { |file| file.puts "Owner manual instruction." }
    protect
    candidate, notes = adaptation_inputs("os/me.md")
    args = ["--only", "foundation", "--adapt", "os/me.md=#{candidate}", "--review", notes]
    assert_includes refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, plan(*args), "--root-backup", @tmp.join("overlap-refused"), "--fork", "os/manual.md=life/manual.md"), "overlaps the exact owner-context adaptation"
    refute @tmp.join("overlap-refused").exist?
    candidate.open("a") { |file| file.puts "Manual fork: life/manual.md." }
    before = UpdateSupport.inventory(@vault)
    backup = apply(plan(*args), "--fork", "os/manual.md=life/manual.md")
    assert_equal candidate.binread, @vault.join("os/me.md").binread
    validate
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_selected_31_custom_governance_requires_narrow_review_without_foundation
    historical(HISTORY_31)
    rules = @vault.join("os/AGENTS.md")
    rules.open("a") { |file| file.puts "\nOwner rule: keep our project terms and never send client messages without approval.\n" }
    protect
    before = UpdateSupport.inventory(@vault)
    proposal = plan("--only", "news-report")
    selection = JSON.parse(proposal.read)
    assert_equal %w[governance news-report validation], selection.fetch("selected_groups")
    assert selection.fetch("entries").find { |entry| entry["path"] == "os/AGENTS.md" }.fetch("governance_review_required")
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--root-backup", @tmp.join("no-governance-review"))
    assert_includes refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--root-backup", @tmp.join("keep-governance"), "--keep", "os/AGENTS.md"), "legacy shared rules require"
    refute @tmp.join("keep-governance").exist?
    candidate = @tmp.join("owner-rules.md")
    candidate.write(rules.read + "\nCurrent authority: inherited Starter.OS-only edit and fork restrictions in this system's manuals, skills, and maps are superseded. Maintain them within owner approval, retaining every independently chosen owner protection.\n")
    notes = @tmp.join("owner-rules-review.md")
    notes.write("The final current-authority paragraph supersedes only inherited product restrictions. All original instructions and project terminology are retained verbatim. Owner approval for client messages remains required. Root and other foundation files stay unchanged.\n")
    backup = apply(plan("--only", "news-report", "--adapt", "os/AGENTS.md=#{candidate}", "--review", notes))
    assert_equal candidate.binread, rules.binread
    %w[AGENTS.md CLAUDE.md os/manual.md os/skill-map.md os/templates/note.md os/me.md].each do |path|
      assert_equal before.fetch(path), UpdateSupport.state(@vault.join(path)), path
    end
    assert_equal "3.1.0", record.fetch("version")
    assert_equal "adapted", record.dig("adoption", "kind")
    validate
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
    apply(plan("--only", "news-report", "--adapt", "os/AGENTS.md=#{candidate}", "--review", notes))
    rules.open("a") { |file| file.puts "\nLater authorized owner maintenance without fork registration.\n" }
    %w[os life].each { |name| commit(@vault.join(name)) }
    current = UpdateSupport.inventory(@vault)
    refute apply(plan("--only", "news-report")).exist?
    assert_equal current, UpdateSupport.inventory(@vault)
    validate
    assert_equal %w[governance validation], JSON.parse(plan("--only", "governance").read).fetch("selected_groups")
  end

  def test_adapted_transaction_interruption_restores_exact_root_and_owner_file_bytes
    historical(HISTORY_31)
    protect
    before = UpdateSupport.inventory(@vault)
    candidate, notes = adaptation_inputs
    injector = @tmp.join("adapt-interrupt.rb")
    injector.write(<<~'RUBY')
      require ENV.fetch("TEST_SUPPORT")
      module InterruptAdaptation
        def atomic_write(root, path, bytes, **options)
          result = super
          raise IOError, "adaptation interruption" if root.to_s == ENV.fetch("TEST_TARGET") && path == ENV.fetch("TEST_BOUNDARY")
          result
        end
      end
      UpdateSupport.singleton_class.prepend(InterruptAdaptation)
    RUBY
    %w[AGENTS.md life/owner-guide.md os/release.json].each_with_index do |boundary, i|
      root = @tmp.join("adapt-root.md")
      root.write(@vault.join("AGENTS.md").read + "\nOwner-approved root extension.\n")
      proposal = plan("--only", "foundation", "--adapt", "AGENTS.md=#{root}", "--adapt", "life/owner-guide.md=#{candidate}", "--review", notes)
      backup = @tmp.join("adapt-interrupted-#{i}")
      output, ok = command("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, proposal, "--root-backup", backup, env: { "RUBYOPT" => "-r#{injector}", "TEST_SUPPORT" => SOURCE.join("setup/scripts/update-support.rb").to_s, "TEST_TARGET" => @vault.to_s, "TEST_BOUNDARY" => boundary })
      refute ok, output
      assert_includes output, "adaptation interruption"
      success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
      assert_equal before, UpdateSupport.inventory(@vault)
    end
  end
end
