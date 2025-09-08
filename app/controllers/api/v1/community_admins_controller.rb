module Api
  module V1
    class CommunityAdminsController < ApiController
      skip_before_action :verify_key!
      before_action :authenticate_with_token!, only: %i[boost_bot_accounts]
      before_action :authenticate_user_from_header, except: %i[boost_bot_accounts]
      before_action :set_community,except: %i[boost_bot_accounts modify_account_status]
      before_action :set_community_admin, only: %i[show update]

      def boost_bot_accounts
        render json: boost_bot_accounts_list
      end

      def index
        authorize @community, :index?
        community_admins = records_filter.get.order(created_at: :desc)
        render json: Api::V1::CommunityAdminSerializer.new(community_admins).serializable_hash.to_json
      end

      def show
        render json: Api::V1::CommunityAdminSerializer.new(@community_admin).serializable_hash, status: :ok
      end

      def update
        if @community_admin.update(community_admin_update_params)
          CommunityAdminPostService.new(@community_admin, current_user, @community).call
          render json: Api::V1::CommunityAdminSerializer.new(@community_admin).serializable_hash, status: :ok
        else
          render_validation_failed(@community_admin.errors)
        end
      end

      def modify_account_status
        @community_admin = current_account&.community_admin
        unless @community_admin || params[:account_status].present?
          return render_not_found
        end

        if @community_admin.update(account_status: params[:account_status])
          handle_account_status_change(@community_admin)
        else
          render_validation_failed(@community_admin.errors)
        end
      rescue StandardError => e
        render_error('api.errors.internal_server_error', :internal_server_error, details: e.message)
      end

      private

      def authenticate_with_token!
        authenticate_or_request_with_http_token do |token, _options|
          static_token = ENV.fetch('STATIC_TOKEN', nil).to_s
          ActiveSupport::SecurityUtils.secure_compare(token, static_token)
        end
      end

      def boost_bot_accounts_list
        result = {}

        communities = Community.where(channel_type: ['channel_feed', 'channel'])
                              .where(deleted_at: nil)

        communities.each do |community|

          community_admin = community.community_admins.first
          next unless community_admin

          if community_admin.is_boost_bot? && community_admin.account_status == "active"
            # Map the channel_type value with correct naming
            channel_type = if community.channel_type == "channel"
                            "community"
                          elsif community.channel_type == "channel_feed"
                            "channel"
                          end

            url = ""
            name = community.name

            if community.channel?
              slug = community.slug.downcase

              if community.is_custom_domain?
                url = "https://#{slug}"
              else
                url = "https://#{slug}.channel.org"
              end
            else
              url = "https://channel.org/@#{community_admin.account.username}"
            end

            account_id = community_admin.account_id

            result[name] = {
              account_id: account_id,
              channel_type: channel_type,
              url: url
            }
          end
        end

        result
      end

      def community_admin_update_params
        params.permit(:email)
      end

      def records_filter
        params[:q] = { patchwork_community_id_eq: @community.id }
        Filter::CommunityAdmin.new(params)
      end

      def set_community_admin
        @community_admin = CommunityAdmin.find_by(id: params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found
      end

      def set_community
        p "COMMUNITY_PARAMS: #{params[:community_id]}"
        @community = Community.find(params[:community_id])
      end

      def handle_account_status_change(community_admin)
        case community_admin.account_status
        when 'deleted'
          community_admin.community.update(visibility: nil)
          render_deleted
        when 'suspended'
          render_success('api.messages.success', :ok, details: 'suspended')
        else
          render_updated
        end
      end
    end
  end
end
