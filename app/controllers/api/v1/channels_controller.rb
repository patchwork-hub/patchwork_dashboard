# frozen_string_literal: true

module Api
  module V1
    class ChannelsController < ApiController
      skip_before_action :verify_key!
      before_action :check_authorization_header, only: [:channel_detail, :channel_feeds, :newsmast_channels, :my_channel, :mo_me_channels, :patchwork_demo_channels, :toot_channels, :bristol_cable_channels, :find_out_channels]
      before_action :set_channel, only: [:channel_detail, :channel_feeds]

      DEFAULT_MO_ME_CHANNELS = [
        { slug: 'mediarevolution', channel_type: Community.channel_types[:channel] },
        { slug: 'newsclubnetwork', channel_type: Community.channel_types[:channel_feed] },
        { slug: 'activism-civil-rights', channel_type: Community.channel_types[:newsmast] },
        { slug: 'climate-change', channel_type: Community.channel_types[:newsmast]},
        { slug: 'politics', channel_type: Community.channel_types[:newsmast]},
        { slug: 'democracy-human-rights', channel_type: Community.channel_types[:newsmast]},
        { slug: 'nature-wildlife', channel_type: Community.channel_types[:newsmast]},
        { slug: 'photography', channel_type: Community.channel_types[:newsmast]}
      ].freeze

      DEFAULT_PATCHWORK_DEMO_CHANNELS = [
        { slug: 'trees', channel_type: Community.channel_types[:channel_feed] },
        { slug: 'podcasting', channel_type: Community.channel_types[:channel_feed] },
        { slug: 'greens', channel_type: Community.channel_types[:channel]},
        { slug: 'fedibookclub', channel_type: Community.channel_types[:channel_feed]},
        { slug: 'NoticiasBrasil', channel_type: Community.channel_types[:channel_feed]},
        { slug: 'RenewedResistance', channel_type: Community.channel_types[:channel]}
      ].freeze

      DEFAULT_TOOT_CHANNELS = [
        { slug: 'newyddion', channel_type: Community.channel_types[:channel_feed] },
        { slug: 'walesnews', channel_type: Community.channel_types[:channel_feed] },
        { slug: 'biodiversity-rewilding', channel_type: Community.channel_types[:newsmast] },
        { slug: 'books-literature', channel_type: Community.channel_types[:newsmast] },
        { slug: 'football', channel_type: Community.channel_types[:newsmast] },
        { slug: 'humour', channel_type: Community.channel_types[:newsmast] },
        { slug: 'movies', channel_type: Community.channel_types[:newsmast] },
        { slug: 'music', channel_type: Community.channel_types[:newsmast] },
        { slug: 'nature-wildlife', channel_type: Community.channel_types[:newsmast] },
        { slug: 'pets', channel_type: Community.channel_types[:newsmast] },
        { slug: 'photography', channel_type: Community.channel_types[:newsmast] },
        { slug: 'sport', channel_type: Community.channel_types[:newsmast] }
      ].freeze

      DEFAULT_BRISTOL_CABLE_CHANNELS = [
        { slug: 'bristol', channel_type: Community.channel_types[:channel_feed] },
        { slug: 'activism-civil-rights', channel_type: Community.channel_types[:newsmast] },
        { slug: 'climate-change', channel_type: Community.channel_types[:newsmast]},
        { slug: 'trees', channel_type: Community.channel_types[:channel_feed] },
        { slug: 'podcasting', channel_type: Community.channel_types[:channel_feed] },
        { slug: 'greens', channel_type: Community.channel_types[:channel]},
        { slug: 'fedibookclub', channel_type: Community.channel_types[:channel_feed]},
        { slug: 'NoticiasBrasil', channel_type: Community.channel_types[:channel_feed]},
        { slug: 'RenewedResistance', channel_type: Community.channel_types[:channel]}
      ].freeze

      DEFAULT_FIND_OUT_CHANNELS = [
        { slug: 'us-politics', channel_type: Community.channel_types[:newsmast] },
        { slug: 'activism-civil-rights', channel_type: Community.channel_types[:newsmast] },
        { slug: 'climate-change', channel_type: Community.channel_types[:newsmast]},
        { slug: 'democracy-human-rights', channel_type: Community.channel_types[:newsmast]},
        { slug: 'news-comment-data', channel_type: Community.channel_types[:newsmast] },
        { slug: 'lgbtq', channel_type: Community.channel_types[:newsmast] },
        { slug: 'us-sport', channel_type: Community.channel_types[:newsmast]}
      ].freeze

      def recommend_channels
        @recommended_channels = Community.recommended.exclude_array_ids
        render json: Api::V1::ChannelSerializer.new(@recommended_channels).serializable_hash.to_json
      end

      def channel_detail
        account = local_account? ? current_account : current_remote_account
        render json: Api::V1::ChannelSerializer.new(
          @channel,
          {
            params: { current_account: account }
          }
         ).serializable_hash.to_json
      end

      def group_recommended_channels
        recommended_group_channels = Collection.recommended_group_channels
        render json: Api::V1::CollectionSerializer.new(recommended_group_channels, { params: { recommended: true, type: 'channel' } }).serializable_hash.to_json
      end

      def search
        query = params[:q].present? ? "%#{params[:q].downcase}%" : nil
        communities = Community
                      .filter_channels
                      .exclude_array_ids
                      .exclude_incomplete_channels
                      .exclude_deleted_channels
                      .where(
                        "lower(name) LIKE :q OR lower(slug) LIKE :q",
                        q: query
                      )
        render json: Api::V1::ChannelSerializer.new(communities).serializable_hash.to_json
      end

      def my_channel
        attached_community = fetch_community_admin&.community
        return render_my_channel_response(channel: nil, channel_feed: nil )if attached_community.nil?

        if attached_community.channel_type == Community.channel_types[:channel]
          render_my_channel_response(channel: attached_community, channel_feed: nil )
        else
          render_my_channel_response(channel: nil, channel_feed: { account: fetch_community_admin&.account, community:  attached_community } )
        end
      end

      def channel_feeds
        channel_feeds = Community.filter_channel_feeds.exclude_incomplete_channels.exclude_deleted_channels.exclude_not_recommended.with_all_includes.ordered_pos_name
        render json: Api::V1::ChannelSerializer.new(channel_feeds , { params: { current_account: current_account } }).serializable_hash.to_json
      end

      def newsmast_channels
        newsmast_channels = Community.filter_newsmast_channels.exclude_incomplete_channels.exclude_deleted_channels.exclude_not_recommended.with_all_includes.ordered_pos_name
        if newsmast_channels.present?
          render json: Api::V1::ChannelSerializer.new(newsmast_channels , { params: { current_account: current_remote_account } }).serializable_hash.to_json
        else
          render json: NEWSMAST_CHANNELS.size > 0 ? { data: NEWSMAST_CHANNELS } : { data: [] }
        end
      end

      def bridge_information
        community = Community.find_by(id: params[:id])
        if community.nil?
          return render_errors('api.community.errors.not_found', :not_found)
        end
        bluesky_info = BlueskyService.new(community).fetch_bluesky_account
        render json: {
          community: community,
          bluesky_info: bluesky_info,
        }
      end

      def mo_me_channels
        render_custom_channels(DEFAULT_MO_ME_CHANNELS)
      end

      def patchwork_demo_channels
        render_custom_channels(DEFAULT_PATCHWORK_DEMO_CHANNELS)
      end

      def toot_channels
        render_custom_channels(DEFAULT_TOOT_CHANNELS)
      end

      def bristol_cable_channels
        render_custom_channels(DEFAULT_BRISTOL_CABLE_CHANNELS)
      end

      def find_out_channels
        render_custom_channels(DEFAULT_FIND_OUT_CHANNELS)
      end

      def starter_packs_channels
        starter_packs_channels = load_json_data(starter_pack_data_path('starter_pack_list.json'))

        render json: { data: starter_packs_channels }
      end

      def starter_packs_detail
        channel_id = params[:id]
        starter_packs_channels = load_json_data(starter_pack_data_path('starter_pack_list.json'))
        channel = starter_packs_channels.find { |ch| ch["id"] == channel_id }

        unless channel
          render json: { error: "Channel not found" }, status: :not_found and return
        end

        followers_file = starter_pack_data_path("starter_pack_#{channel_id}.json")
        followers = load_json_data(followers_file)

        render json: {
          channel: channel,
          followers: followers
        }
      end

      private

      def set_channel
        @channel = Community.find_by(slug: params[:id])
      end

      def fetch_community_admin
        user = current_user
        CommunityAdmin.find_by(account_id: user&.account_id, role: user&.role&.name)
      end

      def render_my_channel_response(channel: nil, channel_feed: nil)
        render json: {
          channel: serialized_channel(channel),
          channel_feed: serialized_channel_feed(channel_feed)
        }
      end

      def serialized_channel(channel)
        channel ? Api::V1::ChannelSerializer.new(channel, {}) : {}
      end

      def serialized_channel_feed(channel_feed)
        if !channel_feed.nil? && channel_feed[:account].present? && channel_feed[:community].present?
          Api::V1::ChannelFeedSerializer.new(channel_feed[:account], { params: { community: channel_feed[:community] } })
        else
          {}
        end
      end

      def check_authorization_header
        if request.headers['Authorization'].present? && params[:instance_domain].present?
          validate_mastodon_account
        else
          authenticate_user_from_header if request.headers['Authorization'].present?
        end
      end

      def render_custom_channels(channels_list)
        account = local_account? ? current_account : current_remote_account

        slugs_with_types = channels_list.map { |entry| [entry[:slug], entry[:channel_type]] }
        communities = Community.where(slug: slugs_with_types.map(&:first), channel_type: slugs_with_types.map(&:last)).exclude_incomplete_channels.with_all_includes

        sorted_communities = channels_list.map do |entry|
          communities.find { |community| community.slug == entry[:slug] && community.channel_type == entry[:channel_type] }
        end.compact

        render json: Api::V1::ChannelSerializer.new(sorted_communities, { params: { current_account: account } }).serializable_hash.to_json
      end

      def load_json_data(filename)
        file_path = Rails.root.join('config', 'data', filename)
        return [] unless File.exist?(file_path)

        # Derive cache key from filename (remove extension)
        cache_key = filename.gsub('/', '_').gsub('.json', '')
        modified_at = File.mtime(file_path).to_i
        full_cache_key = "starter_pack_#{cache_key}_#{modified_at}"

        Rails.cache.fetch(full_cache_key, expires_in: 1.hour) do
          JSON.parse(File.read(file_path))
        end
      end

      def starter_pack_data_path(filename)
        File.join(starter_pack_namespace, filename)
      end

      def starter_pack_namespace
        source = params[:starter_pack_source]
        normalized_source = source.present? ? source.to_s.parameterize(separator: '') : nil

        case normalized_source
        when 'thebristolcable'
          'thebristolcable'
        when 'twt'
          'twt'
        when 'findout'
          'findout'
        else
          'twt'
        end
      end
    end
  end
end
