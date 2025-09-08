require 'csv'

module NewsmastMigration
  class GlobalFilterKeywordJob < ApplicationJob
    queue_as :default
    retry_on StandardError, attempts: 0

    def perform
      csv_path = Rails.root.join('global_filter_keywords.csv')

      unless File.exist?(csv_path)
        Rails.logger.error("CSV file not found at path: #{csv_path}")
        return
      end

      Rails.logger.info(" #{'*'*20} Starting GlobalFilterKeywordJob with CSV file: #{csv_path} #{'*'*20}")

      begin
        CSV.foreach(csv_path, headers: true).with_index(2) do |row, index|
          is_filter_hashtag = ActiveModel::Type::Boolean.new.cast(row['is_filter_hashtag'])
          keywords = row['keyword'].to_s.split(',').map(&:strip)

          Rails.logger.info("Row #{index}: Processing is_filter_hashtag: #{is_filter_hashtag}, keyword count: #{keywords.size}, keywords: #{keywords}")

          keywords.each do |keyword|
            next if keyword.blank?

            begin
              CommunityFilterKeyword.create!(
                patchwork_community_id: nil,
                keyword: keyword,
                filter_type: 'filter_out',
                is_filter_hashtag: is_filter_hashtag
              )
              Rails.logger.info("Row #{index}: Successfully created global CommunityFilterKeyword with keyword: #{keyword}")
            rescue ActiveRecord::RecordInvalid => e
              Rails.logger.error("Row #{index}: Failed to create global CommunityFilterKeyword with keyword: #{keyword}. Error: #{e.message}")
            end
          end
        end
      rescue CSV::MalformedCSVError => e
        Rails.logger.error("Malformed CSV file: #{e.message}")
      rescue StandardError => e
        Rails.logger.error("Unexpected error occurred: #{e.message}")
        raise e
      end

      Rails.logger.info("#{'#'*20} Completed GlobalFilterKeywordJob #{'#'*20}")
    end
  end
end