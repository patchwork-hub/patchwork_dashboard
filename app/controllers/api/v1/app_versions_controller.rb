module Api
  module V1
    class AppVersionsController < ApiController
			skip_before_action :verify_key!
			before_action :check_authorization_header, only: [:check_version]
			before_action :set_app_version, only: %i[check_version]

			def check_version
				return render_error(message: 'Record not found!', status_code: 404) unless @app_version

				unless app_version_params[:os_type].present?
					return render_error(message: 'OS type is required', status_code: 400)
				end

				app_version_history = fetch_version_history
				app_version_history.present? ? render(json: { data: app_version_history }) : render_error(message: 'Record not found!', status_code: 404)	
			end
		
			private
		
				def set_app_version
					key = app_version_params[:app_name]&.to_sym || :mo_me
 					app_name = AppVersion.app_names[key] || AppVersion.app_names[:mo_me]
					@app_version = AppVersion.find_by(
						version_name: app_version_params[:current_app_version],
						app_name: app_name
					)
				end
			
				def render_error(message: "", status_code: 400)
					render json: { error: message }, status: status_code
				end

				def app_version_params
		 			params.permit(:current_app_version, :app_name, :os_type)
				end

				def check_authorization_header
					authenticate_user_from_header if request.headers['Authorization'].present?
				end

				def fetch_version_history
					@app_version.app_version_histories
						.where(os_type: app_version_params[:os_type])
						.order(created_at: :desc)
						.first
				end

		end
	end
end
