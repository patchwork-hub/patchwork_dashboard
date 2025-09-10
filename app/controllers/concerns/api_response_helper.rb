# API Response Helper for internationalized API responses
# This module provides standardized response methods with I18n support for API controllers

module ApiResponseHelper
  extend ActiveSupport::Concern

  private
  # ==================
  # Success responses
  # ==================

  # Success responses with I18n messages
  def render_success(data = {}, message_key = 'api.messages.success', status = :ok, additional_params = {})
    # Use the reusable translation method
    translated_message = get_translated_message(message_key, additional_params)

    response_data = {
      message: translated_message,
      data: data
    }
    
    render json: response_data, status: status
  end

  def render_created(data = {}, message_key = 'api.messages.created')
    render_success(data, message_key, :ok)
  end

  def render_updated(data = {}, message_key = 'api.messages.updated')
    render_success(data, message_key, :ok)
  end

  def render_deleted(message_key = 'api.messages.deleted')
    render_success({}, message_key, :ok)
  end

  # ==================
  # Error responses
  # ==================

  # Error responses with I18n messages and Plural format
  def render_errors(message_key = 'api.errors.unprocessable_entity', status = :unprocessable_entity, additional_data = {})
    # Extract attribute for I18n translation if present
    attribute = additional_data.delete(:attribute) || additional_data.delete('attribute')
    
    # Build translation options
    translation_options = attribute ? { attribute: attribute } : {}
    translated_message = get_translated_message(message_key, translation_options)

    error_data = {
      errors: translated_message,
      **additional_data
    }
    
    render json: error_data, status: status
  end

  # Error responses with I18n messages and single error format
  def render_error(message_key = 'api.errors.unprocessable_entity', status = :unprocessable_entity, additional_data = {})
    # Extract attribute for I18n translation if present
    attribute = additional_data.delete(:attribute) || additional_data.delete('attribute')
    
    # Build translation options
    translation_options = attribute ? { attribute: attribute } : {}
    translated_message = get_translated_message(message_key, translation_options)

    error_data = {
      error: translated_message,
      **additional_data
    }
    
    render json: error_data, status: status
  end


  def render_unauthorized(message_key = 'api.errors.unauthorized')
    render_error(message_key, :unauthorized)
  end

  def render_forbidden(message_key = 'api.errors.forbidden')
    render_error(message_key, :forbidden)
  end

  def render_not_found(message_key = 'api.errors.not_found')
    render_error(message_key, :not_found)
  end

  # Rate limit exceeded error
  def render_rate_limit_exceeded(message_key = 'api.errors.rate_limit_exceeded')
    render_errors(message_key, :too_many_requests)
  end

  # Internal server error with generic message (avoid exposing internal details)
  def render_internal_error(message_key = 'api.errors.internal_server_error')
    render_errors(message_key, :internal_server_error)
  end

  # Validation errors with detailed messages
  def render_validation_failed(errors, message_key = 'api.errors.validation_failed')
    translated_message = get_translated_message(message_key)

    # Clean format with just error message and details array
    error_data = {
      errors: translated_message,
      details: extract_error_messages(errors)
    }
    
    render json: error_data, status: :unprocessable_entity
  end

  # Domain-specific responses
  # Use this when you want to pass a message key for translation
  def render_domain_message_key(message_key = 'api.domain.messages.dns_verified', additional_data = {}, status = :ok)
    # Build translation options
    translation_options = additional_data.slice(:attribute)
    translated_message = get_translated_message(message_key, translation_options)

    domain_data = build_domain_data(translated_message, additional_data)
    render json: domain_data, status: status
  end

  # Helper to build domain response data
  def build_domain_data(message, additional_data)
    case additional_data
    when String
      {
        message: message,
        verified: additional_data == 'true' || additional_data == true
      }
    when Array, Hash
      {
        message: message,
        data: additional_data
      }
    when TrueClass, FalseClass
      {
        message: message,
        verified: additional_data
      }
    else
      {
        message: message,
        **additional_data
      }
    end
  end

  # Locale information for API clients
  def render_locale_info
    render json: {
      current_locale: I18n.locale,
      available_locales: available_locales_with_info,
      fallback_locale: I18n.default_locale
    }
  end

  private

  # Extract clean error messages for the new validation format
  def extract_error_messages(errors)
    case errors
    when ActiveModel::Errors
      errors.full_messages
    when Array
      # Handle array of error messages - flatten and clean
      errors.flatten
    when Hash
      # Handle hash of field-specific errors
      errors.values.flatten
    when String
      # Handle single string error
      [errors]
    else
      # Handle other formats
      [errors.to_s]
    end
  end

  def available_locales_with_info
    I18n.available_locales.map do |locale|
      {
        code: locale,
        name: I18n.t('locale.name', locale: locale),
        native_name: I18n.t('locale.native_name', locale: locale),
        is_default: locale == I18n.default_locale
      }
    end
  rescue I18n::MissingTranslationData
    I18n.available_locales.map { |locale| { code: locale, is_default: locale == I18n.default_locale } }
  end

  # Reusable method for getting translated messages with fallback support
  def get_translated_message(message_key, options = {})
    begin
      # Try to get translation with the provided options
      I18n.t(message_key, **options, raise: true)
    rescue I18n::MissingTranslationData
      # Fallback to English if translation is missing
      I18n.t(message_key, **options, locale: :en, default: message_key.to_s.humanize)
    end
  end
end
