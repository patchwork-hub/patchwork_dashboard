# frozen_string_literal: true
namespace :populate do
    desc 'Populate users with test data'
    task users: :environment do
      domain = ENV['LOCAL_DOMAIN'] || Rails.configuration.x.local_domain
      domain = domain.gsub(/:\d+$/, '')
      1000.times do |i|
        i += 1
        account = Account.where(username: "12SeptUser#{i}").first_or_initialize(username: "12SeptUser#{i}")
        account.save(validate: false)
  
        user = User.where(email: "12SeptUser#{i}@#{domain}").first_or_initialize(
          email: "12SeptUser#{i}@#{domain}",
          password: 'password',
          password_confirmation: 'password',
          confirmed_at: Time.now.utc,
          role: nil,
          account: account,
          agreement: true,
          approved: true
        )
        user.save!
        user.approve!
        Rails.logger.info "Created user #{user.email} successfully"
      end
    end
  end
  