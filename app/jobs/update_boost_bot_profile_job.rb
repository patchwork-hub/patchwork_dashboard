class UpdateBoostBotProfileJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(account_id:, community_id:, is_update: false, attributes: {})
    account = Account.find_by(id: account_id)
    community = Community.find_by(id: community_id)
    community.reload if community.present?

    return if account.nil? || community.nil?

    Rails.logger.info("#{'*' * 10} UpdateBoostBotProfileJob with attributes: #{attributes} #{'*' * 10}" )
    Rails.logger.info("#{'*' * 10} UpdateBoostBotProfileJob with is_update: #{is_update} #{'*' * 10}" )

    token = GenerateAdminAccessTokenService.new(account&.user&.id).call
    return if token.nil?

    avatar_file = attributes[:avatar_changed] ? community.avatar_image : nil
    banner_file = attributes[:banner_changed] ? community.banner_image : nil

    original_avatar_file_name = community.avatar_image_file_name
    original_banner_file_name = community.banner_image_file_name
    Rails.logger.info("#{'*' * 10} UpdateBoostBotProfileJob with original_avatar_file_name: #{original_avatar_file_name}, original_banner_file_name: #{original_banner_file_name} #{'*' * 10}" )  

    UpdateAccountCredentialsService.new.call(
      token: token,
      display_name: attributes[:name] || community.name,
      note: attributes[:description] || community.description,
      avatar: avatar_file,  
      header: banner_file   
    )

    # Mastodon's update_credentials synchronously overwrites the DB rows in patchwork_communities.
    # We must explicitly restore the local Dashboard's original filenames to prevent broken image links.
    filename_updates = {}
    filename_updates[:avatar_image_file_name] = original_avatar_file_name if attributes[:avatar_changed] && original_avatar_file_name.present?
    filename_updates[:banner_image_file_name] = original_banner_file_name if attributes[:banner_changed] && original_banner_file_name.present?
    Rails.logger.info("#{'*' * 10} UpdateBoostBotProfileJob with filename_updates: #{filename_updates} #{'*' * 10}" )  

    community.update_columns(filename_updates) if filename_updates.any?
  end
end