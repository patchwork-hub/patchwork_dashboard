# frozen_string_literal: true

module Api
  module V1
    class ChannelsController < ApiController

      skip_before_action :verify_key!, only: [:recommend_channels, :group_recommended_channels, :search]
      
      def recommend_channels

        recommended_channels = Community.recommended
        render json: Api::V1::ChannelSerializer.new(recommended_channels).serializable_hash.to_json
      
      end

      def group_recommended_channels

        recommended_group_channels = Collection.recommended_group_channels
        render json: Api::V1::CollectionSerializer.new(recommended_group_channels, { params: { recommended: true } }).serializable_hash.to_json
      
      end

      def search

        query = params[:q].present? ? "%#{params[:q].downcase}%" : nil

        communities = Community.where(
          "lower(name) LIKE :q OR lower(slug) LIKE :q",
          q: query
        )

        render json: Api::V1::ChannelSerializer.new(communities).serializable_hash.to_json
        
      end

    end
  end
end