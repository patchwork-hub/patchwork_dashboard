source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '>= 3.0.0'
gem "rails", "~> 7.1.0", ">= 7.0.4.2"
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", "~> 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]
gem "bootsnap", require: false
gem "sassc-rails"

group :development, :test do
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
end

group :development do
  gem "web-console"
  gem "byebug"
  gem "better_errors"
  gem "binding_of_caller"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
end

gem 'responders'
gem 'bootstrap', '~> 4.6.1'

gem 'jquery-rails', '~> 4.6'
gem 'haml'
gem 'simple_form'
gem 'health_check'
gem 'aws-sdk-s3', '~> 1.117', require: false
gem "kaminari"
gem 'devise'
gem 'cancancan'
gem 'kt-paperclip', '~> 7.1'

gem 'dotenv-rails', groups: [:development, :test]
gem 'spreadsheet'
gem 'sidekiq', '~> 6.5'
gem 'hiredis', '~> 0.6'
gem 'redis', '~> 4.5', require: ['redis', 'redis/connection/hiredis']
gem 'httparty'
gem 'sidekiq-scheduler', '~> 5.0'
gem "cocoon"

gem "select2-rails"
gem "strong_migrations"
gem 'patch_commu', git: "https://github.com/newsmast22/patch_commu", branch: 'main'
gem 'ransack'
gem 'bcrypt'
gem 'faraday', '~> 2.10', '>= 2.10.1'
gem 'jsonapi-serializer', '~> 2.2'
