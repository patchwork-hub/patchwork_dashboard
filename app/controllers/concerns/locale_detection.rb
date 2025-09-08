# Locale detection concern for API controllers
# This module provides methods to detect and set the locale based on request headers or parameters

module LocaleDetection
  extend ActiveSupport::Concern

  included do
    # Set locale before each action
    before_action :set_locale
  end

  private

  def set_locale
    # Priority order for locale detection:
    # 1. 'lang' parameter in request
    # 2. Accept-Language header
    # 3. User preference from database (locale field)
    # 4. Default locale

    locale = extract_locale_from_params ||
             extract_locale_from_header ||
             extract_locale_from_user ||
             I18n.default_locale

    # Validate that the locale is supported
    if I18n.available_locales.include?(locale.to_sym)
      I18n.locale = locale
    else
      # Fall back to default locale if requested locale is not supported
      I18n.locale = I18n.default_locale
    end

    # Log locale for debugging in development
    Rails.logger.debug "Locale set to: #{I18n.locale}" if Rails.env.development?
  end

  def extract_locale_from_params
    # Extract locale from 'lang' parameter in request (changed from 'locale' to 'lang')
    params[:lang] if params[:lang].present?
  end

  def extract_locale_from_header
    # Extract locale from Accept-Language header
    # Format: "en-US,en;q=0.9,de;q=0.8,ja;q=0.7"
    return nil unless request.headers['Accept-Language']

    accepted_languages = request.headers['Accept-Language']
                               .split(',')
                               .map { |lang| lang.split(';').first.strip.downcase }

    # Find the first supported language
    accepted_languages.each do |lang|
      # Handle both 'en-US' and 'en' formats
      locale_code = lang.split('-').first
      return locale_code if I18n.available_locales.include?(locale_code.to_sym)
    end

    nil
  end

  def extract_locale_from_user
    # Extract locale from authenticated user's saved preference in database
    # Uses the 'locale' field from the User model
    return nil unless respond_to?(:current_user) && current_user

    # Check if user has a locale preference set and it's supported
    user_locale = current_user.locale
    return user_locale if user_locale.present? && I18n.available_locales.include?(user_locale.to_sym)

    nil
  end

  def available_locales
    # Return available locales as options for frontend
    I18n.available_locales.map do |locale|
      {
        code: locale,
        name: I18n.t('locale.name', locale: locale, default: locale.to_s.upcase),
        native_name: I18n.t('locale.native_name', locale: locale, default: locale.to_s.upcase)
      }
    end
  end

  # Helper method to update user's locale preference in database
  def update_user_locale(locale)
    return false unless respond_to?(:current_user) && current_user
    return false unless I18n.available_locales.include?(locale.to_sym)

    begin
      current_user.update!(locale: locale.to_s)
      Rails.logger.info "Updated user #{current_user.id} locale to: #{locale}" if Rails.env.development?
      true
    rescue => e
      Rails.logger.error "Failed to update user locale: #{e.message}"
      false
    end
  end

  # Helper method to get user's preferred locale
  def user_preferred_locale
    return nil unless respond_to?(:current_user) && current_user
    current_user.locale
  end
end
