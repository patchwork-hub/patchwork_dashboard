# frozen_string_literal: true

class CommunityPostService < BaseService
  def call(account, options = {})
    @account = account
    @options = options
    prepare_slug
    community = unique_slug?
    return community if community.present?

    validate_collection
    create_community
  end

  def validate_collection
    @collection = Collection.find(@options[:collection_id]);
  end

  def create_community
    process_community!
    @community
  end

  def get_position
    last_position = Community.order(:position).pluck(:position).last
    (last_position || 0) + 1
  end

  def get_id
    last_id = Community.order(:id).pluck(:id).last
    (last_id || 0) + 1
  end

  def unique_slug?
    slug = @options[:name].to_s.parameterize.underscore
    community = Community.find_by(slug: slug)
    community
  end

  def prepare_slug
    @slug = @options[:name].parameterize.underscore
  end

  def add_admin!
    process_community_admin!
  end

  def community_attributes
    { id: get_id,
      name: @options[:name],
      slug: @slug,
      description: @options[:bio],
      is_recommended: false,
      guides: nil,
      patchwork_collection_id: @collection.id,
      position: get_position,
      admin_following_count: 0,
      banner_image: @options[:banner_image],
      avatar_image: @options[:avatar_image],
      account_id: @account.id
    }.compact
  end

  def process_community!
    @community = @account.communities.new(community_attributes)
    @community.save!
  end

  def community_admin_attribute
    {
      account_id: @account.id,
      patchwork_community_id: @community.id
    }.compact
  end

  def process_community_admin!
    @community_admin = CommunityAdmin.where(account_id: @account.id, patchwork_community_id: @community.id).first_or_initialize(community_admin_attribute)
    @community_admin.save!
  end
end