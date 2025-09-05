# I18n configuration initializer
# This file sets up internationalization settings for the application

Rails.application.config.after_initialize do
  # Configure I18n exception handler to handle missing translations gracefully
  I18n.exception_handler = lambda do |exception, locale, key, options|
    case exception
    when I18n::MissingTranslation
      # Log missing translations in development/test for debugging
      if Rails.env.development? || Rails.env.test?
        Rails.logger.warn "Missing translation: #{locale}.#{key}"
      end
      
      # Return a user-friendly message or the key itself in production  
      if Rails.env.production?  
        key.to_s.to_s.humanize  
      else  
        "[Missing: #{locale}.#{key}]"  
      end 
    else
      raise exception
    end
  end
end
# Configure pluralization rules for different languages
I18n.backend.store_translations(:en, i18n: { plural: { keys: [:one, :other] } })
I18n.backend.store_translations(:de, i18n: { plural: { keys: [:one, :other] } })
I18n.backend.store_translations(:ja, i18n: { plural: { keys: [:other] } })  # Japanese does have pluralization concepts, but Rails I18n uses only :other because it doesn't distinguish between singular and plural as European languages do
I18n.backend.store_translations(:ru, i18n: { plural: { keys: [:one, :few, :many, :other] } })  # Russian has complex pluralization
I18n.backend.store_translations(:cy, i18n: { plural: { keys: [:zero, :one, :two, :few, :many, :other] } })  # Welsh has complex pluralization
I18n.backend.store_translations(:fr, i18n: { plural: { keys: [:one, :other] } })  # French pluralization
I18n.backend.store_translations(:it, i18n: { plural: { keys: [:one, :other] } })  # Italian pluralization
I18n.backend.store_translations(:pt_BR, i18n: { plural: { keys: [:one, :other] } })  # Brazilian Portuguese
I18n.backend.store_translations(:pt, i18n: { plural: { keys: [:one, :other] } })  # Portuguese
