#!/usr/bin/env ruby

require "fileutils"
require "pathname"
require "date"

script_dir = Pathname.new(__dir__)
vault_root = if script_dir.basename.to_s == "scripts" && %w[os setup].include?(script_dir.parent.basename.to_s)
  script_dir.parent.parent
else
  script_dir.parent
end
businesses = vault_root.join("biz")

def stop(message)
  warn "Cannot add business: #{message}"
  exit 1
end

name = ARGV.shift.to_s.strip
stop("provide one lowercase kebab-case business name") if name.empty?
stop("unexpected options: #{ARGV.join(' ')}") unless ARGV.empty?
stop("use lowercase kebab-case") unless name.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
stop("run this from an installed Starter.OS vault") unless businesses.directory?
stop("businesses may be added only inside a private installed vault") if vault_root.join("setup", "release-manifest.json").exist?

cursor = vault_root
abort "Cannot create through a linked vault" if cursor.symlink?
cursor = cursor.join("biz")
abort "Cannot create through a linked container" if cursor.symlink?

destination = businesses.join(name)
stop("biz/#{name} already exists") if destination.exist? || destination.symlink?

FileUtils.mkdir_p(destination)
today = Date.today.to_s

files = {
  "AGENTS.md" => <<~TEXT,
    # #{name} agent entry

    Read `../../os/AGENTS.md` first. This repository owns the business's strategy, decisions, operations, knowledge, and implementation. Read `status.md` for active work and `knowledge-map.md` only when routing is needed.

    Add rules here only when this business genuinely differs from the shared OS.
  TEXT
  "CLAUDE.md" => "# Agent pointer\n\nRead `AGENTS.md`.\n",
  "readme.md" => <<~TEXT,
    ---
    type: identity
    created: #{today}
    updated: #{today}
    reviewed: #{today}
    status: draft
    authority: canon
    source: ai
    ---

    # #{name.tr('-', ' ')}

    **Bottom line:** Confirm the business purpose and boundaries with the owner.

    **When to read this:** Read for durable business identity and scope.
  TEXT
  "status.md" => <<~TEXT,
    ---
    type: status
    created: #{today}
    updated: #{today}
    reviewed: #{today}
    status: draft
    authority: reference
    source: ai
    ---

    # status

    **Bottom line:** Confirm the business's current state and next priority.

    **When to read this:** Read before substantive work in this business.
  TEXT
  "knowledge-map.md" => <<~TEXT,
    ---
    type: map
    created: #{today}
    updated: #{today}
    reviewed: #{today}
    status: draft
    authority: canon
    source: ai
    ---

    # knowledge map

    **Bottom line:** Route business work to its current authoritative files.

    **When to read this:** Read when the correct business source is unclear.

    - Durable identity and scope: `readme.md`
    - Current state: `status.md`
    - Confirmed decisions: `decisions.md`
  TEXT
  "decisions.md" => <<~TEXT
    ---
    type: decision-log
    created: #{today}
    updated: #{today}
    reviewed: #{today}
    status: living
    authority: canon
    source: ai
    ---

    # decisions

    **Bottom line:** Append only decisions the owner explicitly confirms.

    **When to read this:** Read when current work depends on an earlier business decision.
  TEXT
}

files.each { |path, body| File.write(destination.join(path), body) }
File.write(destination.join(".gitignore"), ".DS_Store\n.env\n.env.*\nnode_modules/\n")
File.write(destination.join(".gitattributes"), "* text=auto eol=lf\n*.md text eol=lf\n")

puts "Created biz/#{name}"
puts "Next: review these files, then protect this business as its own Git repository with a verified private hosted primary. Creation is incomplete until that protection is recorded."
