# frozen_string_literal: true

class Api::V1::ChannelSerializer
  include JSONAPI::Serializer
  include Rails.application.routes.url_helpers

  set_type :channel

  attributes :id, :name, :slug, :description, :is_recommended, :admin_following_count,
             :patchwork_collection_id, :guides, :participants_count, :is_custom_domain,
             :visibility, :position, :channel_type, :created_at, :no_of_admins, :channel_content_type,
             :registration_mode, :patchwork_community_hashtags, :patchwork_community_rules,
             :patchwork_community_additional_informations, :patchwork_community_links, :about, :no_boost_channel

  has_many :patchwork_community_additional_informations, serializer: Api::V1::CommunityAdditionalInformationSerializer
  has_many :patchwork_community_links, serializer: Api::V1::CommunityLinkSerializer
  has_many :patchwork_community_rules, serializer: Api::V1::CommunityRuleSerializer

  attribute :community_type do |object|
    Api::V1::PatchworkCommunityTypeSerializer.new(object.patchwork_community_type).serializable_hash
  end

  attribute :banner_image_url do |object|
    object.slug.present? ? object.banner_image.url : "https://s3-eu-west-2.amazonaws.com/patchwork-prod/explore/science.jpg"
  end

  attribute :avatar_image_url do |object|
    object.slug.present? ? object.avatar_image.url : "https://s3-eu-west-2.amazonaws.com/patchwork-prod/explore/science.jpg"
  end

  attribute :domain_name do |object|
    object.slug.present? ? "#{object.slug}.channel.org" : "channel.org"
  end

  attribute :follower do |object|
    object&.community_admins&.first&.account&.follower_count
  end

  attribute :admin_following_count do |object|
    object&.community_admins&.first&.account&.following_ids&.count
  end

  attribute :no_of_admins do |object|
    object.community_admins.size
  end

  attribute :favourited do |object, params|
    favourited_status(object.id, params[:current_account])
  end

  attribute :favourited_count do |object, params|
    favourited_account_counts(object.id)
  end

  attribute :is_primary do |object, params|
    primary_status(object.id, params[:current_account])
  end

  attribute :community_admin do |object|
    community_admin = object&.community_admins&.first
    username = if object&.channel_type == Community.channel_types[:newsmast]
       community_admin&.account&.username ? "@#{community_admin&.account&.username}@newsmast.community" : ""
    else
      community_admin&.account&.username ? "@#{community_admin&.account&.username}@#{self.default_domain}" : ""
    end
    community_admin ? {
      id: community_admin.id,
      account_id: community_admin&.account&.id.to_s,
      username: username,
    } : {}
  end

  attribute :channel_content_type do |object|
    if object&.content_type&.custom_channel?
      'Curated'
    elsif object&.content_type&.broadcast_channel?
      'Broadcast'
    elsif object&.content_type&.group_channel?
      'Group'
    else
      ''
    end
  end

  private

  def self.default_domain
    case ENV.fetch('RAILS_ENV', nil)
    when 'staging'
      'staging.patchwork.online'
    when 'production'
      'channel.org'
    else
      'localhost.3000'
    end
  end

  def self.favourited_status(channel_id, account)
    return false unless account

    JoinedCommunity.exists?(patchwork_community_id: channel_id, account_id: account['id'])
  end

  def self.primary_status(channel_id, account)
    return false unless account

    JoinedCommunity.exists?(patchwork_community_id: channel_id, is_primary: true, account_id: account['id'])
  end

  def self.favourited_account_counts(channel_id)
    JoinedCommunity.where(patchwork_community_id: channel_id).size
  end
end
