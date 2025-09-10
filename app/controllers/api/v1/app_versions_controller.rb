module Api
  module V1
		class AppVersionsController < ApiController
			skip_before_action :verify_key!
			before_action :authenticate_client_credentials, only: [:check_version]
			before_action :set_app_version, only: %i[check_version]

			def check_version

				unless app_version_params[:os_type].present?
					return render_errors('api.validation.required', :bad_request, { attribute: 'OS type' })
				end

				return render_errors('api.errors.not_found', :not_found) unless @app_version

				app_version_history = fetch_version_history
				if app_version_history.present?
					render_success(app_version_history, 'api.messages.success', :ok)
				else
					render_errors('api.errors.not_found', :not_found)
				end
			end

			private

			def set_app_version
				key = app_version_params[:app_name]&.to_sym || :patchwork
				app_name = AppVersion.app_names[key] || AppVersion.app_names[:patchwork]
				@app_version = AppVersion.find_by(
					version_name: app_version_params[:current_app_version],
					app_name: app_name
				)
			end

			def app_version_params
				params.permit(:current_app_version, :app_name, :os_type)
			end

			def fetch_version_history
				@app_version.app_version_histories
				.where(os_type: app_version_params[:os_type])
				.order(released_date: :desc)
				.first
			end
		end
  end
end
