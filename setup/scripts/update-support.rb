require "digest"
require "fileutils"
require "find"
require "json"
require "open3"
require "pathname"
require "tempfile"
require "securerandom"

# Shared by update and restore. No network, Git writes, or implicit cleanup.
module UpdateSupport
  module_function

  def relative(raw)
    value = raw.to_s
    path = Pathname.new(value)
    raise "unsafe transaction path" if value.empty? || path.absolute? || path.cleanpath.to_s != value || value == "." || value == ".." || value.start_with?("../") || value.split("/").any? { |part| part.downcase == ".git" }
    value
  end

  def safe(root, raw)
    path = root
    raise "linked transaction root" if path.symlink?
    Pathname.new(relative(raw)).each_filename do |part|
      if path.directory?
        alias_name = path.children.map { |child| child.basename.to_s }.find { |name| name.downcase == part.downcase && name != part }
        raise "transaction path uses alternate case: #{raw}" if alias_name
      end
      path = path.join(part)
      raise "transaction path crosses a symbolic link: #{raw}" if path.symlink?
    end
    path
  end

  def state(path)
    return nil unless path.exist? || path.symlink?
    return { "type" => "link", "target" => File.readlink(path) } if path.symlink?
    mode = path.stat.mode & 0o777
    return { "type" => "directory", "mode" => mode } if path.directory?
    raise "unsupported file type: #{path}" unless path.file?
    { "type" => "file", "sha256" => Digest::SHA256.file(path).hexdigest, "mode" => mode }
  end

  def inventory(root)
    files = {}
    Find.find(root.to_s) do |absolute|
      path = Pathname.new(absolute)
      name = path.relative_path_from(root).to_s
      next if name == "."
      if path.basename.to_s == ".git"
        Find.prune if path.directory? && !path.symlink?
        next
      end
      files[name] = state(path)
    end
    files.sort.to_h
  end

  def git_heads(root)
    %w[os life].to_h do |name|
      head, result = Open3.capture2e("git", "-C", safe(root, name).to_s, "rev-parse", "--verify", "HEAD")
      raise "cannot read #{name}/ recovery commit" unless result.success? && head.strip.match?(/\A[0-9a-f]{40,64}\z/)
      [name, head.strip]
    end
  end

  def verify_write_repository(root, raw)
    path = safe(root, raw)
    return if %w[AGENTS.md CLAUDE.md].include?(raw)
    repository = raw.split("/").first
    raise "write is outside the protected repositories: #{raw}" unless %w[os life].include?(repository)
    ancestor = path.parent
    ancestor = ancestor.parent until ancestor.directory?
    top, result = Open3.capture2e("git", "-C", ancestor.to_s, "rev-parse", "--show-toplevel")
    raise "write crosses a repository boundary: #{raw}" unless result.success? && Pathname.new(top.strip).realpath == root.join(repository).realpath
  end

  def temporary_name(raw, transaction_id)
    raise "invalid transaction identity" unless transaction_id.match?(/\A[0-9a-f]{32}\z/)
    path = Pathname.new(relative(raw))
    path.dirname.join(".starter-write-#{transaction_id}-#{Digest::SHA256.hexdigest(raw)[0, 16]}.tmp").to_s
  end

  def atomic_write(root, raw, bytes, mode: 0o644, temporary_path: nil)
    path = safe(root, raw)
    FileUtils.mkdir_p(path.dirname)
    safe(root, raw)
    if temporary_path
      temporary = safe(root, temporary_path)
      created = false
      begin
        File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, mode) do |file|
          created = true
          file.binmode
          file.write(bytes)
          file.flush
          file.fsync
          file.chmod(mode)
        end
        safe(root, raw)
        safe(root, temporary_path)
        File.rename(temporary, path)
      ensure
        File.unlink(temporary) if created && (temporary.exist? || temporary.symlink?)
      end
      return
    end
    Tempfile.create([".starter-write-", ".tmp"], path.dirname.to_s) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      file.fsync
      file.chmod(mode)
      safe(root, raw)
      File.rename(file.path, path)
    end
  end

  def write_receipt(backup, receipt)
    bytes = "#{JSON.pretty_generate(receipt)}\n"
    atomic_write(backup, "receipt.json", bytes, mode: 0o600)
    raise "transaction receipt failed readback" unless JSON.parse(safe(backup, "receipt.json").read) == receipt
  end

  def prepare(root, backup, writes, plan)
    writes.each_key { |raw| verify_write_repository(root, raw) }
    before = inventory(root)
    heads = git_heads(root)
    transaction_id = SecureRandom.hex(16)
    rows = writes.map do |raw, payload|
      path = safe(root, raw)
      old = state(path)
      raise "write destination is not a regular file: #{raw}" if old && old["type"] != "file"
      if old
        copy = safe(backup, "before/#{raw}")
        FileUtils.mkdir_p(copy.dirname)
        FileUtils.cp(path, copy, preserve: true)
        raise "backup readback failed: #{raw}" unless state(copy) == old
      end
      mode = old ? old["mode"] : payload.fetch("mode", 0o644)
      staged = safe(backup, "after/#{raw}")
      FileUtils.mkdir_p(staged.dirname)
      File.binwrite(staged, payload.fetch("bytes"))
      File.chmod(mode, staged)
      expected = { "type" => "file", "sha256" => Digest::SHA256.hexdigest(payload.fetch("bytes")), "mode" => mode }
      raise "staged bytes failed readback: #{raw}" unless state(staged) == expected
      temporary = temporary_name(raw, transaction_id)
      raise "transaction temporary path already exists" if before.key?(temporary) || writes.key?(temporary)
      { "path" => raw, "temporary_path" => temporary, "before" => old, "after" => expected }
    end
    created_dirs = rows.flat_map do |row|
      directory = Pathname.new(row.fetch("path")).parent
      list = []
      until directory.to_s == "."
        list << directory.to_s unless before.key?(directory.to_s)
        directory = directory.parent
      end
      list
    end.uniq.sort
    # Keep the root receipt readable by previous recovery procedures too.
    root_files = %w[AGENTS.md CLAUDE.md].map do |raw|
      path = safe(root, raw)
      old = state(path)
      if old
        raise "root entry is not regular: #{raw}" unless old["type"] == "file"
        FileUtils.cp(path, safe(backup, raw), preserve: true)
        raise "root backup failed readback: #{raw}" unless state(safe(backup, raw)) == old
      end
      { "path" => raw, "existed" => !old.nil?, "sha256" => old && old["sha256"] }
    end
    receipt = {
      "format" => 1, "transaction_format" => 1, "transaction_id" => transaction_id, "product" => "Starter.OS root backup",
      "state" => "prepared", "target_root" => root.to_s,
      "installed_version" => plan.fetch("installed_version"), "target_version" => plan.fetch("target_version"),
      "source_manifest_sha256" => plan.fetch("source_manifest_sha256"),
      "plan_sha256" => Digest::SHA256.hexdigest(JSON.generate(plan)),
      "review_notes_sha256" => plan["review_notes"] && plan["review_notes"]["sha256"],
      "adapted_candidates" => plan.fetch("adaptations", {}).transform_values { |record| record.fetch("sha256") },
      "repositories" => heads, "inventory" => before, "writes" => rows,
      "new_paths" => rows.reject { |row| row["before"] }.map { |row| row["path"] },
      "created_directories" => created_dirs, "files" => root_files
    }
    write_receipt(backup, receipt)
    raise "target changed during backup" unless inventory(root) == before && git_heads(root) == heads
    receipt
  end

  def apply(root, backup, receipt)
    receipt.fetch("writes").each do |row|
      raw = row.fetch("path")
      raise "target changed before write: #{raw}" unless state(safe(root, raw)) == row["before"]
      staged = safe(backup, "after/#{raw}")
      raise "staged bytes changed: #{raw}" unless state(staged) == row.fetch("after")
      atomic_write(root, raw, staged.binread, mode: row.fetch("after").fetch("mode"), temporary_path: row.fetch("temporary_path"))
    end
    expected = receipt.fetch("inventory").dup
    receipt.fetch("writes").each { |row| expected[row.fetch("path")] = row.fetch("after") }
    actual = inventory(root)
    receipt.fetch("created_directories").each do |raw|
      raise "created path is not a directory: #{raw}" unless actual.dig(raw, "type") == "directory"
      expected[raw] = actual[raw]
    end
    raise "unexpected changes after apply; use the recovery receipt" unless actual == expected
    receipt["state"] = "applied"
    write_receipt(backup, receipt)
  end

  def check_restore(root, backup, receipt)
    raise "unsupported transaction receipt" unless receipt["transaction_format"] == 1 && receipt["product"] == "Starter.OS root backup"
    raise "receipt belongs to another installation" unless receipt["target_root"] == root.to_s
    raise "repository commits changed; review later work before restoration" unless git_heads(root) == receipt.fetch("repositories")
    %w[os life].each do |name|
      directory, result = Open3.capture2e("git", "-C", root.join(name).to_s, "rev-parse", "--absolute-git-dir")
      raise "cannot inspect Git operation state" unless result.success?
      %w[MERGE_HEAD REBASE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply sequencer].each do |marker|
        raise "Git operation in progress; stop before restoration" if File.exist?(File.join(directory.strip, marker))
      end
      _output, result = Open3.capture2e("git", "-C", root.join(name).to_s, "diff", "--cached", "--quiet")
      raise "staged work exists; review before restoration" unless result.success?
    end
    writes = receipt.fetch("writes")
    writes.each { |row| verify_write_repository(root, row.fetch("path")) }
    paths = writes.map { |row| relative(row.fetch("path")) }
    raise "duplicate recovery paths" unless paths.uniq == paths
    before = receipt.fetch("inventory")
    actual = inventory(root)
    temporaries = []
    writes.each do |row|
      raw = row.fetch("path")
      safe(root, raw)
      raise "receipt disagrees with protected inventory: #{raw}" unless row["before"] == before[raw]
      raise "later owner changes at #{raw}; preserve and review them first" unless [row["before"], row["after"]].include?(actual[raw])
      %w[before after].each do |side|
        next unless row[side]
        file = safe(backup, "#{side}/#{raw}")
        raise "missing or altered recovery bytes: #{raw}" unless state(file) == row[side]
      end
      temporary = row.fetch("temporary_path")
      raise "invalid transaction temporary path" unless temporary == temporary_name(raw, receipt.fetch("transaction_id")) && !before.key?(temporary)
      temporaries << temporary
      if actual.key?(temporary)
        file = safe(root, temporary)
        raise "unsafe transaction crash remnant" unless file.file? && !file.symlink? && file.stat.nlink == 1
        # A hard interruption may leave any prefix of staged/original bytes.
        # Only the receipt's reserved paths qualify, never a wildcard cleanup.
        matched = %w[before after].any? do |side|
          next false unless row[side]
          saved = safe(backup, "#{side}/#{raw}")
          file.size <= saved.size && File.binread(saved, file.size) == file.binread
        end
        raise "changed transaction crash remnant; preserve owner work" unless matched
      end
    end
    created_dirs = receipt.fetch("created_directories")
    created_dirs.each do |raw|
      relative(raw)
      raise "invalid new directory in receipt" if before.key?(raw) || !paths.any? { |path| path.start_with?("#{raw}/") }
      raise "later change to update directory: #{raw}" if actual[raw] && actual[raw]["type"] != "directory"
    end
    (actual.keys | before.keys).each do |raw|
      next if paths.include?(raw) || created_dirs.include?(raw) || temporaries.include?(raw)
      raise "later owner changes outside the update: #{raw}" unless actual[raw] == before[raw]
    end
    true
  end

  def restore(root, backup, receipt)
    check_restore(root, backup, receipt)
    receipt.fetch("writes").each do |row|
      temporary = safe(root, row.fetch("temporary_path"))
      File.unlink(temporary) if temporary.exist?
    end
    receipt.fetch("writes").reverse_each do |row|
      raw = row.fetch("path")
      if row["before"]
        atomic_write(root, raw, safe(backup, "before/#{raw}").binread, mode: row["before"].fetch("mode"), temporary_path: row.fetch("temporary_path"))
      else
        path = safe(root, raw)
        File.unlink(path) if path.exist?
      end
    end
    receipt.fetch("created_directories").sort_by { |raw| -raw.count("/") }.each do |raw|
      path = safe(root, raw)
      Dir.rmdir(path) if path.directory? && path.children.empty?
    end
    raise "restoration differs from protected inventory" unless inventory(root) == receipt.fetch("inventory")
    receipt["state"] = "restored"
    write_receipt(backup, receipt)
  end
end
