module Api
  module V1
    class AccountsController < ApiController

      def index
        @acounts = Account.includes(user: :role)
                          .where.not(user_roles: {name: ['Moderator', 'Admin', 'Owner']})
                          .page(params[:page] || 1)
                          .per(params[:per_page] || 50)

        options = {}
        options[:meta] = get_metadata(@acounts)
        render json: AccountSerializer.new(@acounts, options)
      end

    end
  end
end
