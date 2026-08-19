# frozen_string_literal: true

module Api
  module V1
    class JoinedWorkingGroupsController < ApiController
      CIVICRM_WORKING_GROUP_IDS_BY_COMMUNITY_NAME = {
        'Atlas' => 20,
        'Community Engagement' => 19,
        'Ethical Framework' => 21,
        'EWS in LMICS' => 22,
        'Models, Data, Methods Repo' => 23,
        'Advisory' => 24,
        'Collaborative' => 25,
        'Communications' => 26,
        'Events' => 27,
        'Finance' => 28,
        'Governance' => 29,
        'Committee - Membership' => 30
      }.freeze

      skip_before_action :verify_key!
      before_action :check_authorization_header
      before_action :set_authenticated_account
      before_action :ensure_civicrm_membership_eligibility!, only: [:create], if: :check_civicrm_membership_enabled?
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
        channel_type = is_channel_feed? ? Community.channel_types[:channel_feed] : Community.channel_types[:channel]

        Community.exclude_incomplete_channels.find_by(slug: slug, channel_type: channel_type)
      end

      def load_joined_channels
        with_read_replica do
          channel_type = is_channel_feed? ? Community.channel_types[:channel_feed] : Community.channel_types[:channel]

          @joined_communities = @account&.communities.where(deleted_at: nil).where(
            channel_type: channel_type
            )
          @community = Community.find_by(slug: params[:id])
        end
      end

      def sort_by_primary!
        with_read_replica do
          @joined_communities = @joined_communities&.to_a || []
          @joined_communities.sort_by! do |community|
            joined = community.joined_communities.find_by(account_id: @account.id)
            joined&.is_primary ? 0 : 1
          end
        end
      end

      def is_newsmast?
        params[:platform_type].present? && params[:platform_type] == 'newsmast.social'
      end

      def is_channel_feed?
        params[:channel_type].present? && params[:channel_type] == Community.channel_types[:channel_feed]
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

      def ensure_civicrm_membership_eligibility!
        patchwork_community = find_patchwork_community(params[:id])
        return render_membership_not_eligible unless patchwork_community

        working_group_id = CIVICRM_WORKING_GROUP_IDS_BY_COMMUNITY_NAME[patchwork_community.name]
        return render_membership_not_eligible unless working_group_id

        email = @account&.user&.email
        return render_membership_not_eligible if email.blank?

        membership_result = CivicrmMembershipCheckService.new(
          email,
          working_group_id: working_group_id,
          force_remote: true
        ).call
        return if membership_result.valid? && membership_result.values_present

        return render_membership_not_eligible if membership_result.error_message.blank?

        render_validation_failed([membership_result.error_message])
      rescue NameError => e
        Rails.logger.error("CiviCRM membership service unavailable: #{e.class} #{e.message}")
        render_membership_not_eligible
      rescue StandardError => e
        Rails.logger.error("CiviCRM membership eligibility check failed: #{e.class} #{e.message}")
        render_membership_not_eligible
      end

      def check_civicrm_membership_enabled?
        raw_value = ENV.fetch('CHECK_CIVICRM_MEMBERSHIP', nil)
        raw_value.present? && ActiveModel::Type::Boolean.new.cast(raw_value)
      end

      def render_membership_not_eligible
        message = I18n.t(
          'api.account.errors.membership_not_eligible',
          default: 'Membership is not eligible for this action'
        )
        render_validation_failed([message])
      end
    end
  end
end
