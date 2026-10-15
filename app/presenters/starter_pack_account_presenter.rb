class StarterPackAccountPresenter
  def initialize(account)
    @account = account
  end

  def as_json(*)
    return nil unless @account

    stats = @account.account_stat
    {
      id: @account.id.to_s, username: @account.username,
      acct: @account.local? ? @account.username : "#{@account.username}@#{@account.domain}",
      display_name: @account.display_name, locked: @account.locked,
      bot: @account.actor_type == 'Service', group: @account.actor_type == 'Group',
      discoverable: @account.discoverable, indexable: @account.indexable,
      created_at: @account.created_at&.iso8601(3), note: @account.note,
      url: @account.url.presence || "#{ENV['MASTODON_INSTANCE_URL']}/@#{@account.username}",
      uri: @account.uri, avatar: @account.avatar_url, avatar_static: @account.avatar_url,
      header: header_url, header_static: header_url,
      followers_count: stats&.followers_count || 0, following_count: stats&.following_count || 0,
      statuses_count: stats&.statuses_count || 0, last_status_at: stats&.last_status_at&.to_date&.iso8601,
      hide_collections: @account.hide_collections, emojis: [], fields: @account.fields || []
    }
  end

  private

  def header_url
    @account.header_remote_url.presence || @account.header.url(:original)
  end
end