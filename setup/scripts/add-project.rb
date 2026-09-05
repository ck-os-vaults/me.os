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
projects = vault_root.join("life", "projects")

def stop(message)
  warn "Cannot add project: #{message}"
  exit 1
end

name = ARGV.shift.to_s.strip
stop("provide one lowercase kebab-case project name") if name.empty?
stop("unexpected options: #{ARGV.join(' ')}") unless ARGV.empty?
stop("use lowercase kebab-case") unless name.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
stop("run this from an installed Starter.OS vault") unless projects.directory?
stop("personal projects may be added only inside a private installed vault") if vault_root.join("setup", "release-manifest.json").exist?

cursor = vault_root
abort "Cannot create through a linked vault" if cursor.symlink?
cursor = cursor.join("life")
abort "Cannot create through a linked container" if cursor.symlink?
cursor = cursor.join("projects")
abort "Cannot create through a linked container" if cursor.symlink?

destination = projects.join(name)
stop("life/projects/#{name} already exists") if destination.exist? || destination.symlink?

FileUtils.mkdir_p(destination)
File.write(destination.join("#{name}.md"), <<~MARKDOWN)
  ---
  type: status
  created: #{Date.today}
  updated: #{Date.today}
  reviewed: #{Date.today}
  status: living
  authority: reference
  source: ai
  ---

  # #{name.tr('-', ' ')}

  **Bottom line:** Define the project's current purpose and state.

  **When to read this:** Read when working on this project.

  ## outcome

  Confirm with the owner.

  ## current state

  Confirm with the owner.

  ## next action

  Confirm with the owner.
MARKDOWN

puts "Created life/projects/#{name}/#{name}.md"
