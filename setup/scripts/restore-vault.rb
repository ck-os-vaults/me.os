#!/usr/bin/env ruby
require_relative "update-support"

begin
  mode, target_raw, backup_raw = ARGV
  raise "usage: restore-vault.rb plan|apply TARGET BACKUP" unless ARGV.length == 3 && %w[plan apply].include?(mode)
  target = Pathname.new(File.expand_path(target_raw))
  backup = Pathname.new(File.expand_path(backup_raw))
  raise "target and backup must be real directories" unless target.directory? && backup.directory? && !target.symlink? && !backup.symlink?
  target = target.realpath
  backup = backup.realpath
  raise "backup must be outside target" if backup == target || backup.to_s.start_with?("#{target}/") || target.to_s.start_with?("#{backup}/")
  receipt = JSON.parse(UpdateSupport.safe(backup, "receipt.json").read)
  UpdateSupport.check_restore(target, backup, receipt)
  if mode == "plan"
    puts "Restore preview: #{receipt.fetch('target_version')} -> protected #{receipt.fetch('installed_version')} state"
    puts "#{receipt.fetch('writes').length} update paths; later owner work is protected by refusal"
    puts "Recovery commits: #{receipt.fetch('repositories').map { |name, head| "#{name}=#{head}" }.join(', ')}"
    puts "No files changed. Apply only after the owner approves this restoration."
  else
    UpdateSupport.restore(target, backup, receipt)
    puts "Restored the complete protected file inventory. Hosted state was not changed or verified."
  end
rescue StandardError => error
  warn "Starter.OS restore stopped: #{error.message}"
  exit 1
end
