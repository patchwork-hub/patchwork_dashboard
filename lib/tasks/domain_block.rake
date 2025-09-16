# lib/tasks/domain_block.rake
require 'csv'

namespace :domain_block do
  desc "Import domain_block.csv into domain_blocks table in chunks of 500"
  task import: :environment do
    file_path = Rails.root.join("public", "csv", "domain_blocks.csv")

    unless File.exist?(file_path)
      puts "CSV file not found: #{file_path}"
      exit
    end

    puts "Starting bulk import (500 per batch) from #{file_path}..."

    existing_domains = DomainBlock.pluck(:domain).to_set
    new_records = []

    # Collect all new records first
    CSV.foreach(file_path, headers: true) do |row|
      domain = row["#domain"]&.strip
      next if domain.blank? || existing_domains.include?(domain)

      new_records << {
        domain:         domain,
        severity:       row.fetch('#severity', :suspend),
        reject_media:   row.fetch('#reject_media', false),
        reject_reports: row.fetch('#reject_reports', false),
        public_comment: row["#public_comment"]&.strip,
        obfuscate:      row.fetch('#obfuscate', false)
      }
    end

    # Insert in batches of 500
    new_records.each_slice(500) do |batch|
      DomainBlock.insert_all(batch)
      puts "Inserted #{batch.size} records..."
    end

    puts "Bulk import completed. Total new: #{new_records.size}"
  end
end
