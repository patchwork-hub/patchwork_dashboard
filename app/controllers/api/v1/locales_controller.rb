module Api
  module V1
    class LocalesController < ApiController
      skip_before_action :verify_key!
      before_action :check_authorization_header

      # GET /api/v1/locale
      # Returns information about available locales and current locale
      def index
        render json: {
          current_locale: I18n.locale,
          default_locale: I18n.default_locale,
          available_locales: formatted_available_locales,
          fallback_locales: I18n.fallbacks.to_h
        }
      end

      # GET /api/v1/locale/:locale
      # Returns detailed information about a specific locale
      def show
        locale = locale_params[:locale]&.to_sym
        
        unless I18n.available_locales.include?(locale)
          render_not_found('api.errors.not_found')
          return
        end

        render json: {
          locale: locale,
          name: I18n.t('locale.name', locale: locale, default: locale.to_s.upcase),
          native_name: I18n.t('locale.native_name', locale: locale, default: locale.to_s.upcase),
          is_default: locale == I18n.default_locale,
          fallback_locale: I18n.fallbacks[locale]&.first
        }
      end

      # POST /api/v1/locale/set
      # Sets the locale for the current session/request using 'lang' parameter
      def set
        locale = locale_params[:lang]&.to_sym
        
        unless I18n.available_locales.include?(locale)
          render_errors('api.errors.invalid_request', :bad_request, {
            available_locales: I18n.available_locales
          })
          return
        end

        I18n.locale = locale
        
        render_success({
          locale: I18n.locale,
          message: I18n.t('api.messages.success')
        })
      end

      # POST /api/v1/locale/save_preference
      # Saves the user's locale preference to database using 'lang' parameter
      def save_preference
        locale = locale_params[:lang]&.to_sym
        unless I18n.available_locales.include?(locale)
          render_errors('api.errors.invalid_request', :bad_request, {
            available_locales: I18n.available_locales
          })
          return
        end

        unless current_user
          render_unauthorized
          return
        end

        # Update user's locale preference
        if current_user.update(locale: locale.to_s)
          I18n.locale = locale
          render_success({
            locale: I18n.locale,
            saved_to_profile: true,
            message: I18n.t('api.messages.updated')
          })
        else
          render_validation_failed(current_user.errors)
        end
      end

      # GET /api/v1/locale/user_preference
      # Returns the current user's saved locale preference
      def user_preference
        unless @account
          render_unauthorized('api.errors.unauthorized')
          return
        end

        user = @account.user if @account.respond_to?(:user)
        
        unless user
          render_errors('api.errors.not_found', :not_found, {
            message: 'User not found for this account'
          })
          return
        end

        render json: {
          user_locale: user.locale,
          current_session_locale: I18n.locale,
          available_locales: formatted_available_locales
        }
      end

      # GET /api/v1/locale/:locale/translations/:namespace
      # Returns translations for a specific namespace
      def translations
        locale_param = params[:locale] || locale_params[:lang] || I18n.locale
        namespace = params[:namespace]
        locale = locale_param&.to_sym
        
        unless I18n.available_locales.include?(locale)
          render_errors('api.errors.invalid_request', :bad_request)
          return
        end

        # Get translations for the specified namespace
        translations = if namespace.present?
          I18n.t(namespace, locale: locale, default: {})
        else
          # Return all translations if no namespace specified (be careful with this)
          I18n.backend.send(:translations)[locale] || {}
        end

        render json: {
          locale: locale,
          namespace: namespace,
          translations: translations
        }
      end

      private

      def locale_params
        params.permit(:namespace, :lang, :instance_domain, :locale, :format)
      end

      def formatted_available_locales
        I18n.available_locales.map do |locale|
          {
            code: locale,
            name: I18n.t('locale.name', locale: locale, default: locale.to_s.upcase),
            native_name: I18n.t('locale.native_name', locale: locale, default: locale.to_s.upcase),
            is_default: locale == I18n.default_locale
          }
        end
      end

      def set_authenticated_account
        if locale_params[:instance_domain].present?
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
