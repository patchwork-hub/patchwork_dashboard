ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require 'mocha/minitest'

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def setup_common_data
    @master_admin = users(:master_admin)
    @hub_admin = users(:hub_admin)
    @org_admin = users(:org_admin)
    @collection = collections(:test_collection)
    @community_type = community_types(:test_type)
  end

  def create_test_community(attributes = {})
    type = attributes.delete(:type) || 'channel'
    user = attributes.delete(:user) || @org_admin
    
    # Convert type to a valid slug format
    slug_type = type.gsub('_', '-')
    unique_id = SecureRandom.uuid[0..7] # Truncate to 8 characters
    
    Community.create!(
      {
        name: "Test #{type.capitalize} #{unique_id}",
        slug: "test-#{slug_type}-#{unique_id}",
        channel_type: type,
        patchwork_collection_id: @collection.id,
        patchwork_community_type_id: @community_type.id,
        description: "Test #{type} description"
      }.merge(attributes)
    )
  end

  def create_test_account(user)
    unique_id = SecureRandom.uuid[0..7] # Truncate to 8 characters
    username = "#{user.email.split('@').first}_#{unique_id}"
    
    # Create a new user if one doesn't exist
    test_user = user || User.create!(
      email: "#{username}@example.com",
      password: 'password123',
      role: 'org_admin'
    )
    
    Account.create!(
      username: username,
      domain: 'example.com',
      user: test_user,
      display_name: username.capitalize,
      note: "Test account for #{username}"
    )
  end
end
