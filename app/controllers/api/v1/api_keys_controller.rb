module Api
  module V1
    class ApiKeysController < ApiController

      def rotate
        @api_key.assign_attributes(api_key_params)
        if @api_key.save(validate: false)
          render_updated({}, 'api.api_key.messages.rotated_successfully')
        else
          render_validation_failed(@api_key.errors, 'api.errors.validation_failed')
        end
      end

      private
      def api_key_params
        params.require(:api_key).permit(:status)
      end

    end
  end
end
