module Api
  module V1
    class SearchController < ApiController
      skip_before_action :verify_key!
      before_action :authenticate_client_credentials, only: [:search]

      def search
        query = build_query(params[:q])

        render json: {
          communities: serialize_communities(query),
          channel_feeds: serialize_channel_feeds(query),
          newsmast_channels: serialize_newsmast_communities(query)
        }
      end

      private

      def build_query(param)
        param.present? ? "%#{param.downcase}%" : nil
      end

      def serialize_communities(query)
        communities = Community
                      .filter_channels
                      .exclude_array_ids
                      .exclude_incomplete_channels
                      .exclude_deleted_channels
                      .exclude_not_recommended
                      .where("lower(name) LIKE :q OR lower(slug) LIKE :q", q: query)

        Api::V1::ChannelSerializer.new(communities).serializable_hash
      end

      def serialize_channel_feeds(query)
        channel_feeds = Community
                        .filter_channel_feeds
                        .exclude_array_ids
                        .exclude_incomplete_channels
                        .exclude_deleted_channels
                        .exclude_not_recommended
                        .where("lower(name) LIKE :q OR lower(slug) LIKE :q", q: query)

        Api::V1::ChannelSerializer.new(channel_feeds, { params: { current_account: current_account } }).serializable_hash
      end

      def serialize_newsmast_communities(query)
        newsmast_communities = Community
                      .filter_newsmast_channels
                      .exclude_array_ids
                      .exclude_incomplete_channels
                      .exclude_deleted_channels
                      .exclude_not_recommended
                      .where("lower(name) LIKE :q OR lower(slug) LIKE :q", q: query)

        Api::V1::ChannelSerializer.new(newsmast_communities).serializable_hash
      end

    end
  end
end
