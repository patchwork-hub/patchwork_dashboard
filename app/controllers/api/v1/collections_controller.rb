# frozen_string_literal: true

module Api
  module V1
    class CollectionsController < ApiController
      skip_before_action :verify_key!
      before_action :fetch_channel_details, only: [:fetch_channels]

      COLLECTION_TYPES = {
        channel: 'channel',
        channel_feed: 'channel_feed',
        newsmast: 'newsmast'
      }.freeze

      NEWSMAST_CHANNELS_SORTING_ORDERS = [
        'Newsmast Channels',
        'News',
        'Global Issues',
        'Government & Politics',
        'Environment',
        'Communities & Allies',
        'Business & Work',
        'Technology',
        'Science',
        'Humanities',
        'Culture',
        'Sport',
        'Lifestyle'
      ].freeze

      def index
        @all_collections = fetch_all_channels_by_type(type: COLLECTION_TYPES[:channel])
        render_collections(@all_collections, type: COLLECTION_TYPES[:channel])
      end

      def channel_feed_collections
        @all_collections = fetch_all_channels_by_type(type: COLLECTION_TYPES[:channel_feed])
        render_collections(@all_collections, type: COLLECTION_TYPES[:channel_feed])
      end

      def newsmast_collections
        @all_collections = fetch_all_channels_by_type(type: COLLECTION_TYPES[:newsmast])
        render_collections(@all_collections, type: COLLECTION_TYPES[:newsmast])
      end

      def fetch_channels
        if @channels
          render json: serialized_channels(type: params[:type])
        else
          render json: { data: [] }
        end
      end

      private

      def fetch_all_channels_by_type(type:)
        collections = case type
        when COLLECTION_TYPES[:channel]
          Collection.filter_by_channel_type(type).order(sorting_index: :asc).to_a
        when COLLECTION_TYPES[:channel_feed]
          Collection.filter_by_channel_type(type).order(sorting_index: :asc).to_a
        else
          newsmast_collections = if Community.has_local_newsmast_channel?
            Collection.filter_by_channel_type(type).order(sorting_index: :asc).to_a
          else
            patchwork_collection_ids = extract_patchwork_collection_ids
            fetch_collections_by_ids(patchwork_collection_ids)
          end
          newsmast_collections = newsmast_collections.sort_by do |collection|
            NEWSMAST_CHANNELS_SORTING_ORDERS.index(collection.name) || Float::INFINITY
          end
          newsmast_collections
        end
        add_all_collection(collections, type: type)
      end

      def extract_patchwork_collection_ids
        NEWSMAST_CHANNELS.map do |channel|
          channel.dig(:attributes, :patchwork_collection_id)
        end.compact
      end

      def fetch_collections_by_ids(ids)
        Collection.where(id: ids).order(sorting_index: :asc).to_a
      end

      def render_collections(collections, type:)
        render json: Api::V1::CollectionSerializer.new(
          collections, params: { recommended: false, type: type }
        ).serializable_hash.to_json
      end

      def serialized_channels(type:)
        if type == COLLECTION_TYPES[:channel] || type == COLLECTION_TYPES[:channel_feed]
          Api::V1::ChannelSerializer.new(@channels).serializable_hash.to_json
        else
          if Community.has_local_newsmast_channel? && params[:type] == COLLECTION_TYPES[:newsmast]
            data = Api::V1::ChannelSerializer.new(@channels).serializable_hash.to_json
            # Need to remove after mobile lunch again
            parsed = JSON.parse(data)
            parsed["data"]
          else
            @channels
          end
        end
      end

      def fetch_channel_details
        return unless params[:slug].present? && params[:type].present?

        @channels = if !Community.has_local_newsmast_channel? && params[:type] == COLLECTION_TYPES[:newsmast]
          fetch_newsmast_channels
        else
          fetch_communities(type:  params[:type])
        end
      end

      def fetch_newsmast_channels
        if params[:slug] == 'all-collection'
          NEWSMAST_CHANNELS.presence
        else
          collection_id = Collection.find_by(slug: params[:slug])&.id
          return nil unless collection_id

          NEWSMAST_CHANNELS.select do |channel|
            channel.dig(:attributes, :patchwork_collection_id) == collection_id
          end
        end
      end

      def fetch_communities(type:)
        base_communities = if params[:slug] == 'all-collection'
          Community.all
        else
          Collection.find_by(slug: params[:slug])&.patchwork_communities
        end
        return [] unless base_communities

        scope = if type == COLLECTION_TYPES[:channel]
          :filter_channels
        elsif type == COLLECTION_TYPES[:channel_feed]
          :filter_channel_feeds
        else
          :filter_newsmast_channels
        end
        base_communities
        .public_send(scope)
        .exclude_array_ids
        .exclude_incomplete_channels
        .exclude_deleted_channels
        .exclude_not_recommended
        .ordered_pos_name
      end

      def add_all_collection(collections, type:)
        name = case type
                  when COLLECTION_TYPES[:channel]
                    'Communities'
                  when COLLECTION_TYPES[:channel_feed]
                    'Channels'
                  else
                    'Newsmast Channels'
                end
        collections.unshift(
          Collection.new(
            id: (collections.last&.id || 1) + 1,
            name: name,
            slug: "all-collection",
            sorting_index: 0,
            created_at: nil,
            updated_at: nil
          )
        )
        collections
      end
    end
  end
end
