require 'test_helper'

class CommunityPostServiceTest < ActiveSupport::TestCase
  def setup
    setup_common_data
    @service = CommunityPostService.new
    create_test_account(@hub_admin) unless @hub_admin.account.present?
  end

  test "creates hub community successfully" do
    options = {
      name: 'Test Hub',
      slug: 'test-hub',
      channel_type: 'hub',
      content_type: 'broadcast_channel',
      bio: 'Test hub description'
    }

    community = @service.call(@hub_admin, options)
    
    assert community.persisted?, "Hub community should be created successfully"
    assert_equal 'hub', community.channel_type
    assert_nil community.patchwork_collection_id
    assert_nil community.patchwork_community_type_id
    assert_equal 'broadcast_channel', community.content_type.channel_type
  end

  test "creates non-hub community successfully" do
    options = {
      name: 'Test Channel',
      slug: 'test-channel',
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: @community_type.id,
      content_type: 'custom_channel',
      bio: 'Test channel description'
    }

    community = @service.call(@hub_admin, options)
    
    assert community.persisted?, "Non-hub community should be created successfully"
    assert_equal 'channel', community.channel_type
    assert_equal @collection.id, community.patchwork_collection_id
    assert_equal @community_type.id, community.patchwork_community_type_id
    assert_not_nil community.content_type, "Content type should be created"
    assert_equal 'custom_channel', community.content_type.channel_type
    assert_equal 'or_condition', community.content_type.custom_condition
  end

  test "fails to create non-hub community without collection" do
    options = {
      name: 'Test Channel',
      slug: 'test-channel',
      channel_type: 'channel',
      community_type_id: @community_type.id,
      bio: 'Test channel description'
    }

    community = @service.call(@hub_admin, options)
    
    assert_not community.persisted?, "Non-hub community should not be created without collection"
    assert_includes community.errors[:patchwork_collection_id], "is required for non-hub communities"
  end

  test "fails to create non-hub community without community type" do
    options = {
      name: 'Test Channel',
      slug: 'test-channel',
      channel_type: 'channel',
      collection_id: @collection.id,
      bio: 'Test channel description'
    }

    community = @service.call(@hub_admin, options)
    
    assert_not community.persisted?, "Non-hub community should not be created without community type"
    assert_includes community.errors[:patchwork_community_type_id], "is required for non-hub communities"
  end

  test "creates content type for hub community" do
    options = {
      name: 'Test Hub',
      slug: 'test-hub',
      channel_type: 'hub',
      content_type: 'broadcast_channel',
      bio: 'Test hub description'
    }

    community = @service.call(@hub_admin, options)
    
    assert community.persisted?, "Hub community should be created successfully"
    assert_not_nil community.content_type, "Content type should be created"
    assert_equal 'broadcast_channel', community.content_type.channel_type
  end

  test "creates content type for non-hub community" do
    options = {
      name: 'Test Channel',
      slug: 'test-channel',
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: @community_type.id,
      content_type: 'custom_channel',
      bio: 'Test channel description'
    }

    community = @service.call(@hub_admin, options)
    
    assert community.persisted?, "Non-hub community should be created successfully"
    assert_not_nil community.content_type, "Content type should be created"
    assert_equal 'custom_channel', community.content_type.channel_type
  end

  test "updates existing community successfully" do
    community = create_test_community(
      name: 'Original Name',
      slug: 'original-slug',
      description: 'Original description'
    )
    
    options = {
      id: community.id,
      name: 'Updated Name',
      slug: 'updated-slug',
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: @community_type.id,
      bio: 'Updated description',
      registration_mode: 'none',
      visibility: 'public_access',
      content_type: 'custom_channel'
    }

    updated_community = @service.call(@hub_admin, options)
    
    assert updated_community.persisted?, "Community should be updated successfully. Errors: #{updated_community.errors.full_messages.join(', ')}"
    assert_equal 'Updated Name', updated_community.name
    assert_equal 'original-slug', updated_community.slug, "Slug should not be updated"
    assert_equal 'Updated description', updated_community.description
  end

  test "fails to update community with duplicate name" do
    first_community = create_test_community
    community = create_test_community
    original_name = community.name
    
    options = {
      id: community.id,
      name: first_community.name,
      slug: community.slug,
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: @community_type.id
    }

    updated_community = @service.call(@hub_admin, options)
    
    assert_equal original_name, updated_community.name, "Community name should not be updated with duplicate name"
    assert_includes updated_community.errors[:name], "has already been taken"
  end

  test "fails to update community with duplicate slug" do
    first_community = create_test_community
    community = create_test_community
    original_slug = community.slug
    
    options = {
      id: community.id,
      name: community.name,
      slug: first_community.slug,
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: @community_type.id
    }

    updated_community = @service.call(@hub_admin, options)
    
    assert_equal original_slug, updated_community.slug, "Community slug should not be updated with duplicate slug"
    assert_includes updated_community.errors[:slug], "has already been taken"
  end

  test "handles collection not found error" do
    options = {
      name: 'Test Channel',
      slug: 'test-channel',
      channel_type: 'channel',
      collection_id: 999999,
      community_type_id: @community_type.id
    }

    community = @service.call(@hub_admin, options)
    assert_not community.persisted?, "Community should not be created without a valid collection"
    assert_includes community.errors[:patchwork_collection_id], "is required for non-hub communities"
  end

  test "handles community type not found error" do
    options = {
      name: 'Test Channel',
      slug: 'test-channel',
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: 999999
    }

    community = @service.call(@hub_admin, options)
    assert_not community.persisted?, "Community should not be created without a valid community type"
    assert_includes community.errors[:patchwork_community_type_id], "is required for non-hub communities"
  end

  test "increments IP address use count" do
    ip_address = IpAddress.create!(
      ip: '192.168.1.1',
      use_count: 0
    )
    assert_equal 0, ip_address.use_count, "IP address should start with use_count of 0"
    
    # Ensure hub admin has a valid account
    @hub_admin.account ||= Account.find_by(username: 'hub')
    @hub_admin.save!
    
    # Ensure collection and community type exist
    @collection ||= Collection.create!(
      name: 'Test Collection',
      description: 'Test collection description'
    )
    @community_type ||= CommunityType.create!(
      name: 'Test Type',
      description: 'Test type description'
    )
    
    # Create a unique name and slug using UUID
    unique_id = SecureRandom.uuid[0..7]
    unique_name = "Test Community #{unique_id}"
    unique_slug = "test-community-#{unique_id}"
    
    options = {
      name: unique_name,
      slug: unique_slug,
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: @community_type.id,
      ip_address_id: ip_address.id,
      description: 'Test community description',
      registration_mode: 'none',
      visibility: 'public_access',
      content_type: 'custom_channel'
    }

    community = @service.call(@hub_admin, options)
    assert community.persisted?, "Community should be created successfully. Errors: #{community.errors.full_messages.join(', ')}"
    
    ip_address.reload
    assert_equal 1, ip_address.use_count, "IP address use_count should be incremented to 1"
  end

  test "assigns correct position to new community" do
    # Create first community with unique name and slug
    create_test_community(
      name: 'First Test Community',
      slug: 'first-test-community',
      position: 1
    )
    
    # Create second community with unique name and slug
    create_test_community(
      name: 'Second Test Community',
      slug: 'second-test-community',
      position: 2
    )
    
    # Create new community with unique name and slug
    options = {
      name: 'Third Test Community',
      slug: 'third-test-community',
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: @community_type.id,
      description: 'Test community description',
      registration_mode: 'none',
      visibility: 'public_access',
      content_type: 'custom_channel'
    }

    community = @service.call(@hub_admin, options)
    assert community.persisted?, "Community should be created successfully. Errors: #{community.errors.full_messages.join(', ')}"
    assert_equal 3, community.position
  end

  test "get_position assigns correct position when no communities exist" do
    # Ensure no communities exist
    Community.delete_all
    
    options = {
      name: 'First Community',
      slug: 'first-community',
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: @community_type.id,
      description: 'Test community description',
      registration_mode: 'none',
      visibility: 'public_access',
      content_type: 'custom_channel'
    }

    community = @service.call(@hub_admin, options)
    assert community.persisted?, "Community should be created successfully. Errors: #{community.errors.full_messages.join(', ')}"
    assert_equal 1, community.position, "First community should get position 1"
  end

  test "get_position assigns correct position when communities have gaps" do
    # Create communities with positions 1 and 3, leaving a gap
    create_test_community(
      name: 'First Test Community',
      slug: 'first-test-community',
      position: 1
    )
    
    create_test_community(
      name: 'Third Test Community',
      slug: 'third-test-community',
      position: 3
    )
    
    # Create new community
    options = {
      name: 'New Community',
      slug: 'new-community',
      channel_type: 'channel',
      collection_id: @collection.id,
      community_type_id: @community_type.id,
      description: 'Test community description',
      registration_mode: 'none',
      visibility: 'public_access',
      content_type: 'custom_channel'
    }

    community = @service.call(@hub_admin, options)
    assert community.persisted?, "Community should be created successfully. Errors: #{community.errors.full_messages.join(', ')}"
    assert_equal 4, community.position, "New community should get position after the highest existing position"
  end
end