# Exact owner-reviewed adaptations. This does not infer or merge instructions.
module UpdateAdaptations
  module_function

  def input(raw, target, source)
    path = Pathname.new(File.expand_path(raw))
    current = path
    loop do
      raise "adaptation input crosses a symbolic link" if current.symlink?
      break if current.parent == current
      current = current.parent
    end
    raise "adaptation input must be a regular file" unless path.file?
    path = path.realpath
    [target, source].each do |root|
      raise "adaptation inputs must be outside source and target" if path == root || path.to_s.start_with?("#{root}/")
    end
    { "input" => path.to_s, "sha256" => Digest::SHA256.file(path).hexdigest, "mode" => path.stat.mode & 0o777 }
  end

  def review(target, source, mappings, notes, entries)
    raise "adaptations require --review preservation notes" if !mappings.empty? && notes.to_s.empty?
    raise "review notes require an adaptation" if mappings.empty? && notes
    return [{}, nil] if mappings.empty?
    records = {}
    mappings.each do |raw, file|
      path = UpdateSupport.relative(raw)
      raise "adaptation is outside os/, life/, or root agent files" unless path.start_with?("os/", "life/") || %w[AGENTS.md CLAUDE.md].include?(path)
      raise "adaptation targets generated or configuration content" if path.downcase == "os/release.json" || path.split("/").any? { |part| part.start_with?(".") } || path.end_with?(".lock")
      raise "duplicate or case-aliased adaptation" if records.keys.any? { |key| key.downcase == path.downcase }
      target_path = UpdateSupport.safe(target, path)
      raise "adaptation destination is not a regular file" if target_path.exist? && !target_path.file?
      # Git boundaries are checked during planning, before any transaction exists.
      UpdateSupport.verify_write_repository(target, path)
      entry = entries.find { |row| row["path"] == path }
      raise "adaptation targets an unselected artifact: #{path}" if entry && entry["action"] == "not-selected"
      records[path] = input(file, target, source)
    end
    review = input(notes, target, source)
    raise "preservation notes must not be empty" if File.read(review.fetch("input")).strip.empty?
    [records.sort.to_h, review]
  end

  def bytes(record)
    path = Pathname.new(record.fetch("input"))
    raise "reviewed adaptation input changed" unless !path.symlink? && path.file? && Digest::SHA256.file(path).hexdigest == record.fetch("sha256") && (path.stat.mode & 0o777) == record.fetch("mode")
    path.binread
  end
end
