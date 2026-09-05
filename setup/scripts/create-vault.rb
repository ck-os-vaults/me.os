#!/usr/bin/env ruby

require "digest"
require "fileutils"
require "json"
require "pathname"
require "time"
require "open3"

SOURCE_ROOT = Pathname.new(File.expand_path("../..", __dir__)).realpath
MANIFEST_PATH = SOURCE_ROOT.join("setup", "release-manifest.json")

def stop(message)
  warn "Cannot create vault: #{message}"
  exit 1
end

def safe_relative(raw)
  value = raw.to_s.strip
  stop("release manifest contains a blank path") if value.empty?
  path = Pathname.new(value)
  clean = path.cleanpath.to_s
  stop("release manifest contains an unsafe path: #{value}") if path.absolute? || clean == ".." || clean.start_with?("../") || clean != value
  clean
end

def sha256(path)
  Digest::SHA256.file(path).hexdigest
end

def artifact_bytes(source, artifact, destination)
  bytes = File.binread(source)
  return bytes unless artifact["render"]

  stop("unknown artifact renderer: #{artifact['render']}") unless artifact["render"] == "system-name"
  marker = "{{SYSTEM_NAME}}"
  stop("system-name template is missing its marker: #{artifact['source']}") unless bytes.include?(marker)
  bytes.gsub(marker, destination.basename.to_s)
end

def inside?(path, root)
  path == root || path.to_s.start_with?("#{root}/")
end

def canonical_destination(path)
  stop("the destination itself may not be a symbolic link") if path.symlink?

  missing = []
  current = path
  until current.exist?
    stop("the destination path contains a broken symbolic link: #{current}") if current.symlink?
    parent = current.parent
    stop("cannot resolve the destination path") if parent == current
    missing.unshift(current.basename.to_s)
    current = parent
  end

  stop("the destination path contains a symbolic link: #{current}") if current.symlink?
  missing.reduce(current.realpath) { |resolved, part| resolved.join(part) }
end

def safe_source(root, relative)
  current = root
  Pathname.new(relative).each_filename do |part|
    current = current.join(part)
    stop("source path crosses a symbolic link: #{relative}") if current.symlink?
  end
  stop("source path is missing: #{relative}") unless current.file?
  stop("source path escapes the public source: #{relative}") unless inside?(current.realpath, root)
  current
end

allow_unreleased = !!ARGV.delete("--allow-unreleased")
raw_destination = ARGV.shift
stop("provide the full destination ending in .os") if raw_destination.to_s.strip.empty?
stop("unexpected options: #{ARGV.join(' ')}") unless ARGV.empty?

destination = canonical_destination(Pathname.new(File.expand_path(raw_destination)))
source_real = SOURCE_ROOT

stop("the root folder name must end in .os") unless destination.basename.to_s.match?(/\A.+\.os\z/i)
stop("the private vault must be outside the public source") if inside?(destination, source_real)
stop("the destination exists and is not a folder") if destination.exist? && !destination.directory?
stop("the destination folder is not empty") if destination.directory? && !destination.children.empty?
stop("release manifest is missing; run ruby setup/scripts/build-release-manifest.rb") unless MANIFEST_PATH.file?

checked, status = Open3.capture2e("ruby", SOURCE_ROOT.join("setup/scripts/validate-source.rb").to_s)
stop("source integrity check failed: #{checked.strip}") unless status.success?
manifest = JSON.parse(MANIFEST_PATH.read)
stop("this source is an unreleased candidate; explicitly approve --allow-unreleased or use an approved released source") if manifest["status"] != "released" && !allow_unreleased
stop("unsupported release manifest") unless manifest["format"] == 1 && manifest["product"] == "Starter.OS"
stop("release manifest has no version") if manifest["version"].to_s.strip.empty?

artifacts = manifest.fetch("artifacts")
seen = {}
artifacts.each do |artifact|
  target = safe_relative(artifact.fetch("path"))
  source = safe_relative(artifact.fetch("source"))
  stop("duplicate installed path: #{target}") if seen[target]
  seen[target] = true

  source_path = safe_source(SOURCE_ROOT, source)
  stop("source checksum changed; rebuild the release manifest: #{source}") unless sha256(source_path) == artifact.fetch("sha256")
end

FileUtils.mkdir_p(destination)
stop("the destination changed while it was being created") unless destination.realpath == destination
manifest.fetch("directories", []).each do |relative|
  FileUtils.mkdir_p(destination.join(safe_relative(relative)))
end

artifacts.each do |artifact|
  source = safe_source(SOURCE_ROOT, safe_relative(artifact.fetch("source")))
  target = destination.join(safe_relative(artifact.fetch("path")))
  FileUtils.mkdir_p(target.dirname)
  if artifact["render"]
    File.binwrite(target, artifact_bytes(source, artifact, destination))
  else
    FileUtils.cp(source, target, preserve: true)
  end
end

release_record = {
  "format" => 1,
  "product" => "Starter.OS",
  "version" => manifest.fetch("version"),
  "installed_at" => Time.now.utc.iso8601,
  "manifest_sha256" => sha256(MANIFEST_PATH),
  "installed_source" => { "version" => manifest.fetch("version"), "manifest_sha256" => sha256(MANIFEST_PATH) },
  "artifacts" => artifacts.to_h do |artifact|
    path = artifact.fetch("path")
    target = destination.join(path)
    [
      path,
      {
        "ownership" => artifact.fetch("ownership"),
        "sha256" => sha256(target),
        "upstream_sha256" => artifact.fetch("sha256"),
        "source_version" => manifest.fetch("version")
      }
    ]
  end
}
release_path = destination.join("os", "release.json")
FileUtils.mkdir_p(release_path.dirname)
release_path.write("#{JSON.pretty_generate(release_record)}\n")

puts "Created #{destination.basename} at #{destination}"
puts "Installed Starter.OS #{manifest.fetch('version')}"
puts "Next: establish and verify the approved Git baseline and private hosted copy before substantial personalization."
puts "If Git was declined or deferred, honor that choice and record the protection gap; do not initialize Git to pass a check."
puts "Then personalize confirmed context and validate: use ruby os/validate-starter-os.rb for standard setup, or add --foundation for explicit Git decline/deferral."
