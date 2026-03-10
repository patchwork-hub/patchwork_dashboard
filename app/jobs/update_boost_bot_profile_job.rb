class UpdateBoostBotProfileJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(account_id:, community_id:, is_update: false, attributes: {})
    account = Account.find_by(id: account_id)
    community = Community.find_by(id: community_id)
    return if account.nil? || community.nil?

    token = GenerateAdminAccessTokenService.new(account&.user&.id).call
    return if token.nil?

    avatar_file = decode_base64_to_file(attributes[:avatar_base64], attributes[:avatar_filename])
    banner_file = decode_base64_to_file(attributes[:banner_base64], attributes[:banner_filename])

    original_avatar_file_name = community.avatar_image_file_name
    original_banner_file_name = community.banner_image_file_name

    UpdateAccountCredentialsService.new.call(
      token: token,
      display_name: attributes[:name] || community.name,
      note: attributes[:description] || community.description,
      avatar: avatar_file,  
      header: banner_file   
    )

    # Mastodon's update_credentials synchronously overwrites the DB rows in patchwork_communities.
    # We must explicitly restore the local Dashboard's original filenames to prevent broken image links.
    community.reload
    filename_updates = {}
    filename_updates[:avatar_image_file_name] = original_avatar_file_name if original_avatar_file_name.present?
    filename_updates[:banner_image_file_name] = original_banner_file_name if original_banner_file_name.present?
    community.update_columns(filename_updates) if filename_updates.any?

  ensure
    delete_temp_file(avatar_file)
    delete_temp_file(banner_file)
  end

  private

  def decode_base64_to_file(base64_data, filename)
    return nil unless base64_data.present?

    require 'fileutils'
    require 'base64'
    tmp_dir = Rails.root.join('tmp', 'job_uploads', SecureRandom.hex(8))
    FileUtils.mkdir_p(tmp_dir)
    file_path = File.join(tmp_dir, filename || "image_#{SecureRandom.hex(4)}.jpg")

    File.open(file_path, 'wb') do |f|
      f.write(Base64.strict_decode64(base64_data))
    end
    
    File.open(file_path, 'rb')
  rescue StandardError => e
    Rails.logger.error("Failed to decode base64 file #{filename}: #{e.message}")
    nil
  end
  
  def delete_temp_file(file)
    return unless file.present? && File.exist?(file.path)
    File.delete(file.path)
  rescue StandardError => e
    Rails.logger.error("Failed to delete temp file: #{e.message}")
  end
end