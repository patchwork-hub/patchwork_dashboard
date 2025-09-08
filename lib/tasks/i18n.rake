# Rake tasks for I18n testing and management
# These tasks help validate and manage the internationalization implementation

namespace :i18n do
  desc "Test I18n implementation with all supported languages"
  task test: :environment do
    puts "=== Patchwork Dashboard I18n Implementation Test ==="
    puts "Testing internationalization with #{I18n.available_locales.count} languages"
    puts

    # Test 1: Available locales
    puts "1. Available Locales:"
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        name = I18n.t('locale.name', default: locale.to_s.upcase)
        native_name = I18n.t('locale.native_name', default: locale.to_s.upcase)
        puts "   #{locale}: #{name} (#{native_name})"
      end
    end
    puts

    # Test 2: Critical API messages
    puts "2. Testing Critical API Messages:"
    test_keys = [
      'api.errors.unauthorized',
      'api.errors.not_found', 
      'api.errors.validation_failed',
      'api.messages.success',
      'api.community.errors.only_one_channel',
      'api.community.messages.created'
    ]

    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        puts "   #{locale.to_s.upcase}:"
        test_keys.each do |key|
          translation = I18n.t(key, default: '[MISSING]')
          status = translation == '[MISSING]' ? '❌' : '✅'
          puts "     #{status} #{key}: #{translation}"
        end
        puts
      end
    end

    # Test 3: Model validation coverage
    puts "3. Testing Model Validation Coverage:"
    validation_keys = [
      'activerecord.errors.models.community.attributes.name.blank',
      'activerecord.errors.models.community.attributes.name.taken',
      'activerecord.errors.models.user.attributes.locale.invalid'
    ]

    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        puts "   #{locale.to_s.upcase}:"
        validation_keys.each do |key|
          translation = I18n.t(key, default: '[MISSING]')
          status = translation == '[MISSING]' ? '❌' : '✅'
          puts "     #{status} #{key}"
        end
        puts
      end
    end

    puts "=== Test Complete ==="
    puts "Use 'rake i18n:missing_keys' to find missing translations"
  end

  desc "Find missing translation keys across all locales"
  task missing_keys: :environment do
    puts "=== Missing Translation Keys Report ==="
    
    # Get all keys from English (reference locale)
    english_translations = I18n.backend.send(:translations)[:en]
    all_keys = extract_keys(english_translations)
    
    missing_report = {}
    
    I18n.available_locales.each do |locale|
      next if locale == :en
      
      locale_translations = I18n.backend.send(:translations)[locale] || {}
      locale_keys = extract_keys(locale_translations)
      missing_keys = all_keys - locale_keys
      
      if missing_keys.any?
        missing_report[locale] = missing_keys
      end
    end
    
    if missing_report.empty?
      puts "✅ All translations are complete!"
    else
      missing_report.each do |locale, keys|
        puts "\n❌ #{locale.to_s.upcase} - Missing #{keys.count} translations:"
        keys.sort.each { |key| puts "   - #{key}" }
      end
    end
    
    puts "\n=== Report Complete ==="
  end

  desc "Validate translation file syntax"
  task validate_syntax: :environment do
    puts "=== Translation File Syntax Validation ==="
    
    locale_files = Dir[Rails.root.join('config', 'locales', '*.yml')]
    errors = []
    
    locale_files.each do |file|
      begin
        YAML.load_file(file)
        puts "✅ #{File.basename(file)} - Valid YAML syntax"
      rescue Psych::SyntaxError => e
        errors << "❌ #{File.basename(file)} - YAML Error: #{e.message}"
        puts errors.last
      rescue => e
        errors << "❌ #{File.basename(file)} - Error: #{e.message}"
        puts errors.last
      end
    end
    
    if errors.empty?
      puts "\n✅ All translation files have valid syntax!"
    else
      puts "\n❌ Found #{errors.count} syntax errors:"
      errors.each { |error| puts "   #{error}" }
      exit 1
    end
  end

  desc "Generate locale statistics"
  task stats: :environment do
    puts "=== Internationalization Statistics ==="
    puts
    
    puts "Configuration:"
    puts "  Default locale: #{I18n.default_locale}"
    puts "  Available locales: #{I18n.available_locales.join(', ')}"
    puts "  Total languages: #{I18n.available_locales.count}"
    puts
    
    # Count translations per locale
    puts "Translation counts per locale:"
    I18n.available_locales.each do |locale|
      translations = I18n.backend.send(:translations)[locale] || {}
      key_count = extract_keys(translations).count
      puts "  #{locale}: #{key_count} keys"
    end
    puts
    
    # File sizes
    puts "Translation file sizes:"
    locale_files = Dir[Rails.root.join('config', 'locales', '*.yml')]
    locale_files.each do |file|
      size_kb = File.size(file) / 1024.0
      puts "  #{File.basename(file)}: #{size_kb.round(1)} KB"
    end
    
    puts "\n=== Statistics Complete ==="
  end

  def extract_keys(hash, prefix = '')
    keys = []
    hash.each do |key, value|
      current_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      if value.is_a?(Hash)
        keys.concat(extract_keys(value, current_key))
      else
        keys << current_key
      end
    end
    keys
  end
end
