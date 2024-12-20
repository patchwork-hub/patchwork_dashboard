# frozen_string_literal: true

module Api
  module V1
    class ChannelsController < ApiController
      skip_before_action :verify_key!, only: [:recommend_channels, :group_recommended_channels, :search, :channel_detail, :my_channel]

      before_action :authenticate_user_from_header, only: [:my_channel]
      before_action :set_channel, only: [:channel_detail]
      
      def recommend_channels
        @recommended_channels = Community.recommended.exclude_array_ids
        render json: Api::V1::ChannelSerializer.new(@recommended_channels).serializable_hash.to_json
      end

      def channel_detail
        render json: Api::V1::ChannelSerializer.new(@channel).serializable_hash.to_json
      end

      def group_recommended_channels
        recommended_group_channels = Collection.recommended_group_channels
        render json: Api::V1::CollectionSerializer.new(recommended_group_channels, { params: { recommended: true } }).serializable_hash.to_json
      end

      def search
        query = params[:q].present? ? "%#{params[:q].downcase}%" : nil
        communities = Community
                      .filter_channels
                      .exclude_array_ids
                      .exlude_incomplete_channels
                      .where(
                        "lower(name) LIKE :q OR lower(slug) LIKE :q",
                        q: query
                      )
        render json: Api::V1::ChannelSerializer.new(communities).serializable_hash.to_json
      end

      def my_channel
        attached_community = fetch_community_admin&.community
        return render_my_channel_response(channel: main_channel, channel_feed: nil )if attached_community.nil?

        if attached_community.channel_type == Community.channel_types[:channel]
          render_my_channel_response(channel: attached_community, channel_feed: nil )
        else
          render_my_channel_response(channel: nil, channel_feed: { account: fetch_community_admin&.account, community:  attached_community } )
        end
      end

      private 

      def set_channel 
        @channel = Community.find_by(slug: params[:id])
      end

      def main_channel
        Community.new(
          id: (Community.last&.id || 1) + 1,
          name: "Main channel",
          slug: "",
          description: "",
          is_recommended: true,
          admin_following_count: 0,
          patchwork_collection_id: nil,
          position: 0,
          guides: {},
          participants_count: 0,
          visibility: 0,
          created_at: nil,
          updated_at: nil
        )
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

    end
  end
end