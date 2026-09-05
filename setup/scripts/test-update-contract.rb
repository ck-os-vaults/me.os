#!/usr/bin/env ruby
require "minitest/autorun"
require "tmpdir"
require_relative "update-support"

class UpdateContractTest < Minitest::Test
  SOURCE = Pathname.new(File.expand_path("../..", __dir__)).realpath
  HISTORY = "01f60e03b4ad22b4f9135051df57d73f8a7701f4"

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
    @tmp = Pathname.new(Dir.mktmpdir("starter-contract-"))
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
    assert_includes %w[2.0.0 2.1.0 3.0.0], manifest.fetch("version")
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
    assert_equal "3.1.0", record.fetch("version")
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
    assert_original_version_update_and_restore("dd03a11", "2.1.0")
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
    assert_equal "forked", record.fetch("artifacts").fetch(custom).fetch("ownership")
    assert_equal SOURCE.join(stock_path).binread, @vault.join(stock_path).binread
    validate
    success("ruby", SOURCE.join("setup/scripts/restore-vault.rb"), "apply", @vault, backup)
    assert_equal before, UpdateSupport.inventory(@vault)
  end

  def test_candidate_is_not_silently_installed_or_applied
    refusal("ruby", SOURCE.join("setup/scripts/create-vault.rb"), @vault)
    refute @vault.exist?
    historical
    protect
    refusal("ruby", SOURCE.join("setup/scripts/update-vault.rb"), "apply", @vault, plan, "--root-backup", @tmp.join("unapproved"))
    refute @tmp.join("unapproved").exist?
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
    assert_equal "3.1.0", record.fetch("version")
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
    assert_equal ["news-report"], parsed.fetch("selected_groups")
    assert_equal "partial", parsed.fetch("adoption")
    backup = apply(proposal)
    assert_equal "3.0.0", record.fetch("version")
    assert_equal "3.1.0", record.fetch("adoption").fetch("offered_version")
    changed = JSON.parse(backup.join("receipt.json").read).fetch("writes").map { |row| row.fetch("path") }
    assert_empty changed - %w[os/skills/news-report.md os/release.json]
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
    assert_equal "managed", record.fetch("artifacts").fetch(path).fetch("ownership")
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
    manifest["version"] = "3.2.0"
    manifest["supported_updates"] << "3.2.0"
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
    assert_equal "3.2.0", fork.fetch("available_upstream").fetch("version")
    assert_equal owner_bytes, @vault.join(path).binread
    %w[os life].each { |name| commit(@vault.join(name)) }
    reviewed = plan(source: source)
    refute JSON.parse(reviewed.read).fetch("entries").find { |row| row["path"] == path }.fetch("upstream_changed")
    apply(reviewed, "--replace", path, source: source)
    assert_equal "managed", record.fetch("artifacts").fetch(path).fetch("ownership")
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
    assert_equal %w[foundation news-report], selection.fetch("selected_groups")
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
end
