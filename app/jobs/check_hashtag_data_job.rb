class CheckHashtagDataJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "--- Checking for missing tag follows ---"
    count_missing = 0

    results_missing = CommunityAdmin
      .where(is_boost_bot: true)
      .where.not(account_id: nil)
      .joins(:community)
      .joins("INNER JOIN patchwork_communities_hashtags pch ON pch.patchwork_community_id = patchwork_communities_admins.patchwork_community_id")
      .joins("LEFT JOIN tags t ON lower(t.name) = lower(pch.hashtag)")
      .joins("LEFT JOIN tag_follows tf ON tf.tag_id = t.id AND tf.account_id = patchwork_communities_admins.account_id")
      .select(
        "patchwork_communities.name AS community_name",
        "patchwork_communities_admins.username AS boost_bot_username",
        "pch.hashtag AS community_tag",
        "CASE WHEN tf.id IS NOT NULL THEN true ELSE false END AS is_followed"
      )

    results_missing.each do |record|
      unless record.is_followed
        Rails.logger.info "🚨 Missing follow found -> Community: '#{record.community_name}' | Bot ID: #{record.boost_bot_username} | Tag: #{record.community_tag}"
        count_missing += 1
      end
    end

    Rails.logger.info "\nFinished check. Found #{count_missing} missing tag follows.\n\n"

    Rails.logger.info "--- Checking for unexpected tag follows ---"
    count_unexpected = 0

    results_unexpected = CommunityAdmin
      .where(is_boost_bot: true)
      .where.not(account_id: nil)
      .joins(:community)
      .joins("INNER JOIN tag_follows tf ON tf.account_id = patchwork_communities_admins.account_id")
      .joins("INNER JOIN tags t ON t.id = tf.tag_id")
      .joins("LEFT JOIN patchwork_communities_hashtags pch ON pch.patchwork_community_id = patchwork_communities_admins.patchwork_community_id AND lower(pch.hashtag) = lower(t.name)")
      .select(
        "patchwork_communities.name AS community_name",
        "patchwork_communities_admins.account_id AS bot_account_id",
        "t.id AS tag_id",
        "t.name AS tag_name",
        "CASE WHEN pch.id IS NULL THEN true ELSE false END AS is_unexpected"
      )

    results_unexpected.each do |record|
      if record.is_unexpected
        Rails.logger.info "⚠️ Unexpected follow found -> Community: '#{record.community_name}' | Bot ID: #{record.bot_account_id} | Tag: #{record.tag_name}"
        count_unexpected += 1
      end
    end

    Rails.logger.info "\nFinished check. Found #{count_unexpected} unexpected tag follows."
  end
end
