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
        return render_errors('api.joined_communities.errors.channel_not_found', :not_found) unless patchwork_community

        if already_favorited?(patchwork_community)
          return render_errors('api.joined_communities.errors.already_favorited', :forbidden)
        end

        @joined_community = JoinedCommunity.new(joined_community_params.merge(patchwork_community_id: patchwork_community.id))
        if @joined_community.save
          render_success({}, 'api.joined_communities.messages.favorited_successfully')
        else
          render_validation_failed(@joined_community.errors)
        end
      end

      def destroy
        patchwork_community = find_patchwork_community(params[:id])
        return render_errors('api.joined_communities.errors.channel_not_found', :not_found) unless patchwork_community
        
        @joined_community = JoinedCommunity.find_by(patchwork_community_id: patchwork_community.id, account_id: @account.id)
        if @joined_community
          @joined_community.destroy
          render_success({}, 'api.joined_communities.messages.unfavorited_successfully')
        else
          render_errors('api.joined_communities.errors.favorited_channel_not_found', :not_found)
        end
      end

      def set_primary
        unless is_newsmast?
          return render_errors('api.joined_communities.errors.no_access_set_primary', :forbidden)
        end

        unless @joined_communities&.any?
          return render_errors('api.joined_communities.errors.no_favorited_channels', :bad_request)
        end
        
        unless @community
          return render_errors('api.joined_communities.errors.community_not_found', :not_found)
        end

        if @account.joined_communities.size < 5
          return render_errors('api.joined_communities.errors.minimum_channels_required', :forbidden)
        end

        ActiveRecord::Base.transaction do
          @account.joined_communities.where(is_primary: true).update_all(is_primary: false)
          joined_community = @account.joined_communities.find_by(patchwork_community_id: @community.id)
          joined_community.update!(is_primary: true)
        end

        render_success({}, 'api.joined_communities.messages.primary_set_successfully')
      rescue ActiveRecord::RecordInvalid => e
        render_validation_failed([e.message])
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
          
          return render_unauthorized unless @account
          
          @account
        end
    end
  end
end
