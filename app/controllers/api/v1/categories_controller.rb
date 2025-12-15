module Api
  module V1
    class CategoriesController < ApiController
      skip_before_action :verify_key!

      # get latest print edition
      def bristol_latest_print
        render json: {
          categoryId: 4482,
          title: 'Latest Print Edition',
          categoryType: 'list'
        }
      end
    end
  end
end
