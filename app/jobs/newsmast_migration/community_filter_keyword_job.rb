require 'csv'

module NewsmastMigration
  class CommunityFilterKeywordJob < ApplicationJob
    queue_as :default
    retry_on StandardError, attempts: 0

    def perform
      csv_path = Rails.root.join('community_filter_keywords.csv')

      unless File.exist?(csv_path)
        Rails.logger.error("CSV file not found at path: #{csv_path}")
        return
      end

      Rails.logger.info(" #{'*'*20} Starting NewsmastFilterKeywordJob with CSV file: #{csv_path} #{'*'*20}")

      begin
        CSV.foreach(csv_path, headers: true).with_index(2) do |row, index|
          community_slug = row['community_id']
          is_filter_hashtag = ActiveModel::Type::Boolean.new.cast(row['is_filter_hashtag'])
          keywords = row['keyword'].to_s.split(',').map(&:strip)

          Rails.logger.info("Row #{index}: Processing community_slug: #{community_slug}, is_filter_hashtag: #{is_filter_hashtag}, keyword count: #{keywords.size}, keywords: #{keywords}")

          community = Community.find_by(slug: community_slug)
          if community.nil?
            Rails.logger.warn("Row #{index}: Community not found for slug: #{community_slug}")
            next
          end

          keywords.each do |keyword|
            next if keyword.blank?

            begin
              CommunityFilterKeyword.create!(
                patchwork_community_id: community.id,
                keyword: keyword,
                filter_type: 'filter_out',
                is_filter_hashtag: is_filter_hashtag
              )
              Rails.logger.info("Row #{index}: Successfully created CommunityFilterKeyword for community_id: #{community.id}, keyword: #{keyword}")
            rescue ActiveRecord::RecordInvalid => e
              Rails.logger.error("Row #{index}: Failed to create CommunityFilterKeyword for community_id: #{community.id}, keyword: #{keyword}. Error: #{e.message}")
            end
          end
        end
      rescue CSV::MalformedCSVError => e
        Rails.logger.error("Malformed CSV file: #{e.message}")
      rescue StandardError => e
        Rails.logger.error("Unexpected error occurred: #{e.message}")
        raise e
      end

      Rails.logger.info("#{'#'*20} Completed NewsmastFilterKeywordJob #{'#'*20}")
    end
  end
end