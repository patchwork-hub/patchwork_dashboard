# frozen_string_literal: true

module Api
  module V1
    class JoinedCommunitiesController < ApiController
      skip_before_action :verify_key!
      before_action :check_authorization_header
      before_action :set_authenticated_account
      before_action :load_joined_channels, only: [:index, :set_primary]

      def index
        sort_by_primary!

        render json: Api::V1::ChannelSerializer.new(
          @joined_communities,
          { params: { current_account: @account},
            meta: { total: @joined_communities.size }
          }
        ).serializable_hash.to_json
      end

      def create
        patchwork_community = find_patchwork_community(params[:id])
        return render json: { errors: 'Channel not found' }, status: 404 unless patchwork_community

        if already_favorited?(patchwork_community)
          render json: { errors: 'You can\'t favorite own channel' }, status: 403
          return
        end

        @joined_community = JoinedCommunity.new(joined_community_params.merge(patchwork_community_id: patchwork_community.id))
        if @joined_community.save
          render json: { message: 'Channel has been favorited successfully'}, status: 200
        else
          render json: { errors: @joined_community.errors.full_messages }, status: 422
        end
      end

      def destroy
        patchwork_community = find_patchwork_community(params[:id])
        return render json: { errors: 'Channel not found' }, status: 404 unless patchwork_community
        
        @joined_community = JoinedCommunity.find_by(patchwork_community_id: patchwork_community.id, account_id: @account.id)
        if @joined_community
          @joined_community.destroy
          render json: { message: 'Favourited channel successfully deleted' }, status: 200
        else
          render json: { errors: 'Favourited channel not found' }, status: 404
        end
      end

      def set_primary
        
        unless is_newsmast?
          render json: { errors: 'You have no access to set primary' }, status: 422
        end

        unless @joined_communities&.any?
          return render json: { errors: 'You have no favourited channels' }, status: 422
        end
        
        unless @community
          return render json: { errors: 'Community not found' }, status: 404
        end

        if @account.joined_communities.size < 5
          return render json: { errors: 'You need to join at least 5 to set as primary' }, status: 422
        end

        ActiveRecord::Base.transaction do
          @account.joined_communities.where(is_primary: true).update_all(is_primary: false)
          joined_community = @account.joined_communities.find_by(patchwork_community_id: @community.id)
          joined_community.update!(is_primary: true)
        end
        render json: { message: 'Channel has been set as primary successfully' }, status: 200
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.message }, status: 422
      end
      
      private

        def already_favorited?(patchwork_community)
          return false if params[:instance_domain].present?
        
          CommunityAdmin.exists?(
            patchwork_community_id: patchwork_community.id,
            account_id: @account.id
          )
        end

        def joined_community_params
          params.permit(:account_id).merge(account_id: @account.id)
        end

        def find_patchwork_community(slug)
          return unless slug.present?
          channel_type = is_newsmast? ? Community.channel_types[:newsmast] : Community.channel_types[:channel]

          Community.exclude_incomplete_channels.find_by(slug: slug, channel_type: channel_type)
        end

        def load_joined_channels
          channel_type = is_newsmast? ? Community.channel_types[:newsmast] : Community.channel_types[:channel]
          @joined_communities = @account&.communities.where(deleted_at: nil).where(
            channel_type: channel_type
            )
          @community = Community.find_by(slug: params[:id])
        end

        def sort_by_primary!
          @joined_communities = @joined_communities&.to_a || []
          @joined_communities.sort_by! do |community|
            joined = community.joined_communities.find_by(account_id: @account.id)
            joined&.is_primary ? 0 : 1
          end
        end

        def is_newsmast?
          params[:platform_type].present? && params[:platform_type] == 'newsmast.social'
        end

        def set_authenticated_account
          if params[:instance_domain].present?
            @account = current_remote_account
          else
            @account = current_account
          end
          unless @account
            return render json: { errors: 'Account not found' }, status: 404
          end
          @account
        end
    end
  end
end
