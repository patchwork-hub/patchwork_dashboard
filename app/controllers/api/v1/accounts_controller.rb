module Api
  module V1
    class AccountsController < ApiController

      def index
        with_read_replica do
          @accounts = Account.joins("INNER JOIN users ON accounts.id = users.account_id")
                            .joins("LEFT JOIN user_roles ON users.role_id = user_roles.id")
                            .where("user_roles.name NOT IN (?) OR users.role_id IS NULL", ['Moderator', 'Admin', 'Owner'])

          @accounts = @accounts.where("accounts.created_at >= :date
                                        OR accounts.suspended_at >= :date
                                        OR users.confirmed_at >= :date",
                                        date: params[:last_synced_at]
                                      ) if params[:last_synced_at].present?

          @accounts = @accounts.page(params[:page] || 1).per(params[:per_page] || 50)

          options = {}
          options[:meta] = get_metadata(@accounts)
          render json: Api::V1::AccountSerializer.new(@accounts, options)
        end
      end

    end
  end
end
