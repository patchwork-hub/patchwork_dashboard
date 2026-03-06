class UpdateBoostBotProfileJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(account_id:, community_id:, is_update: false)
    account = Account.find_by(id: account_id)
    community = Community.find_by(id: community_id)
    return if account.nil? || community.nil?

    token = GenerateAdminAccessTokenService.new(account&.user&.id).call
    return if token.nil?

    UpdateAccountCredentialsService.new.call(
    token: token,
    display_name: community.name,
    note: community.description,
    avatar: community.avatar_image,  # Paperclip attachment
    header: community.banner_image   # Paperclip attachment
    )

    unless is_update
      actor_type = community.hub? ? "Application" : "Service"
      account = Account.find_by(id: account_id)
      return if account.nil?

      account.update!(
        username: community.slug.parameterize.underscore,
        actor_type: actor_type,
        discoverable: true
      )
    end
  end
end