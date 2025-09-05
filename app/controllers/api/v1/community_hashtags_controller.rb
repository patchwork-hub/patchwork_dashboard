module Api
  module V1
    class CommunityHashtagsController < ApiController
      skip_before_action :verify_key!
      before_action :authenticate_user_from_header
      before_action :set_community
      before_action :set_community_hashtag, only: %i[update destroy]

      def index
        authorize @community, :index?
        @records = load_commu_hashtag_records
        render json: {
          data: @records,
          meta: {
            current_page: @records.current_page,
            total_pages: @records.total_pages,
            per_page: @records.limit_value,
            total_count: @records.total_count
          }
        }, status: :ok
      end

      def create
        begin
          hashtag = params.require(:community_hashtag).require(:hashtag).gsub('#', '')
          perform_hashtag_action(hashtag, @community.id, :follow)

          render_created({}, 'api.community_hashtags.messages.created')
        rescue CommunityHashtagPostService::InvalidHashtagError
          render_error('api.community_hashtags.errors.invalid_hashtag', :unprocessable_entity)
        rescue ActiveRecord::RecordNotUnique
          render_error('api.community_hashtags.errors.duplicate_hashtag', :conflict)
        rescue ActionController::ParameterMissing
          render_error('api.community_hashtags.errors.parameter_missing', :bad_request)
        end
      end

      def update
        begin
          hashtag = params.require(:community_hashtag).require(:hashtag).gsub('#', '')
          if hashtag.include?(' ')
            render_error('api.community_hashtags.errors.cannot_contain_spaces', :unprocessable_entity)
            return
          end
          return if performed?

          perform_hashtag_action(@community_hashtag.hashtag, @community.id, :unfollow)
          @community_hashtag.assign_attributes(hashtag: hashtag, name: hashtag, patchwork_community_id: @community.id)
          @community_hashtag.save!
          perform_hashtag_action(@community_hashtag.hashtag, @community.id, :follow)

          render_updated({}, 'api.community_hashtags.messages.updated')
        rescue CommunityHashtagPostService::InvalidHashtagError
          render_error('api.community_hashtags.errors.invalid_hashtag', :unprocessable_entity)
        rescue ActiveRecord::RecordNotUnique
          render_error('api.community_hashtags.errors.duplicate_hashtag', :conflict)
        rescue ActionController::ParameterMissing
          render_error('api.community_hashtags.errors.parameter_missing', :bad_request)
        end
      end

      def destroy
        begin
          return if performed?
          perform_hashtag_action(@community_hashtag.hashtag, nil, :unfollow)
          @community_hashtag.destroy!
          render_deleted('api.community_hashtags.messages.deleted')
        rescue StandardError
          render_internal_error
        end
      end

      private

      PER_PAGE = 5

      def set_community
        if params[:community_id].blank?
          render_error('api.community_hashtags.errors.community_required', :bad_request)
          return
        end

        community_param = params[:community_id]
        @community = Community.find_by(slug: community_param)

        unless @community
          @community = Community.find_by(id: community_param.to_i) if community_param.to_i.to_s == community_param
        end

        unless @community
          render_error('api.community_hashtags.errors.community_not_found', :not_found)
          return
        end

        @api_base_url = ENV.fetch('MASTODON_INSTANCE_URL')
        @token = bearer_token
      end

      def set_community_hashtag
        @community_hashtag = @community.patchwork_community_hashtags.find(params[:id])
      end

      def community_hashtag_params
        params.require(:community_hashtag).permit(:hashtag, :community_id)
      end

      def load_commu_hashtag_records
        @community.patchwork_community_hashtags
          .order(created_at: :desc)
          .page(params[:page])
          .per(params[:per_page] || PER_PAGE)
      end

      def perform_hashtag_action(hashtag_name, community_id = nil, action)
        if action == :follow && community_id && !@community_hashtag.present?
          CommunityHashtagPostService.new.call(hashtag: hashtag_name, community_id: community_id)
        end

        hashtag = SearchHashtagService.new(@api_base_url, @token, hashtag_name).call
        return unless hashtag

        service_class = action == :follow ? FollowHashtagService : UnfollowHashtagService
        service_class.new(@api_base_url, @token, hashtag[:name]).call

        perform_relay_action(hashtag_name, community_id, action)
      end

      def perform_relay_action(hashtag_name, community_id, action)
        # Owner account's user id
        owner_role = UserRole.find_by(name: 'Owner')
        owner_user = User.find_by(role: owner_role)
        token = fetch_oauth_token(owner_user.id)

        if action == :follow
          create_relay(hashtag_name, token)
        end

        if action == :unfollow
          unless CommunityHashtag.where(name: hashtag_name).where.not(patchwork_community_id: community_id).exists?
            delete_relay(hashtag_name, token)
          end
        end
      end

      def create_relay(hashtag_name, token)
        inbox_url = "https://relay.fedi.buzz/tag/#{hashtag_name}"
        unless Relay.exists?(inbox_url: inbox_url)
          CreateRelayService.new(@api_base_url, token, hashtag_name).call
        end
      end

      def delete_relay(hashtag_name, token)
        inbox_url = "https://relay.fedi.buzz/tag/#{hashtag_name}"
        relay = Relay.find_by(inbox_url: inbox_url)
        if relay
          DeleteRelayService.new(@api_base_url, token, relay.id).call
        end
      end

      def fetch_oauth_token(user_id)
        token_service = GenerateAdminAccessTokenService.new(user_id)
        token_service.call
      end

    end
  end
end
