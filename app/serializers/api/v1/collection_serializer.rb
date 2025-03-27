# frozen_string_literal: true

class Api::V1::CollectionSerializer
  include JSONAPI::Serializer
  include Rails.application.routes.url_helpers

  set_type :collection

  attributes :id,
              :name,
              :slug,
              :sorting_index

  attribute :community_count do |object, params|
    if params[:type] == 'newsmast'
      newsmast_community_count(object)
    elsif params[:type] == 'channel_feed'
      default_community_count(object, params)
    else
      default_community_count(object, params)
    end
  end

  attribute :banner_image_url do |object|
    object.banner_image.url
  end

  attribute :avatar_image_url do |object|
    object.avatar_image.url
  end

  attribute :channels do |object, params|
    if params[:type] == 'newsmast'
      newsmast_channels(object)
    elsif params[:type] == 'channel_feed'
      default_channels(object, params)
    else
      default_channels(object, params)
    end
  end

  private

  def self.newsmast_community_count(object)
    if object.slug == "all-collection"
      NEWSMAST_CHANNELS.size
    else
      NEWSMAST_CHANNELS.select { |channel| channel[:attributes][:patchwork_collection_id] == object.id }.size
    end
  end

  def self.default_community_count(object, params)
    if object.slug == "all-collection" && params[:type] == 'channel'
      Community.filter_channels.exclude_array_ids.exclude_incomplete_channels.size
    elsif object.slug == "all-collection" && params[:type] == 'channel_feed'
      Community.filter_channel_feeds.exclude_array_ids.exclude_incomplete_channels.size
    else
      object.patchwork_communities.exclude_array_ids.filter_channels.exclude_incomplete_channels.size
    end
  end

  def self.newsmast_channels(object)
    if object.slug == "all-collection"
      { data: [] }
    else
      { data: NEWSMAST_CHANNELS.select { |channel| channel[:attributes][:patchwork_collection_id] == object.id } }
    end
  end

  def self.default_channels(object, params)
    communities = case params[:type]
                  when 'channel'
                    if params[:recommended]
                      object.patchwork_communities.filter_channels.exclude_array_ids.exclude_incomplete_channels.recommended
                    else
                      object.patchwork_communities.filter_channels.exclude_array_ids.exclude_incomplete_channels.ordered_pos_name
                    end
                  when 'channel_feed'
                    object.patchwork_communities.filter_channel_feeds.exclude_array_ids.exclude_incomplete_channels.ordered_pos_name
                  else
                    []
                  end
  
    Api::V1::ChannelSerializer.new(communities).serializable_hash
  end

end
