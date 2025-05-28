require 'test_helper'

class CommunityTest < ActiveSupport::TestCase
  def setup
    setup_common_data
  end

  # Validation Tests
  test "validates name presence" do
    community = Community.new(
      slug: 'test-community',
      channel_type: 'channel',
      patchwork_collection_id: @collection.id,
      patchwork_community_type_id: @community_type.id
    )
    assert_not community.valid?
    assert_includes community.errors[:name], "can't be blank"
  end

  test "validates name uniqueness" do
    first_community = create_test_community
    community = Community.new(
      name: first_community.name,
      slug: 'test-community-2',
      channel_type: 'channel',
      patchwork_collection_id: @collection.id,
      patchwork_community_type_id: @community_type.id
    )
    assert_not community.valid?
    assert_includes community.errors[:name], "has already been taken"
  end

  test "validates slug presence" do
    community = Community.new(
      name: 'Test Community',
      channel_type: 'channel',
      patchwork_collection_id: @collection.id,
      patchwork_community_type_id: @community_type.id
    )
    assert_not community.valid?
    assert_includes community.errors[:slug], "can't be blank"
  end

  test "validates slug uniqueness" do
    first_community = create_test_community
    community = Community.new(
      name: 'Test Community 2',
      slug: first_community.slug,
      channel_type: 'channel',
      patchwork_collection_id: @collection.id,
      patchwork_community_type_id: @community_type.id
    )
    assert_not community.valid?
    assert_includes community.errors[:slug], "has already been taken"
  end

  # Channel Type Tests
  test "hub community can be created without collection" do
    community = Community.new(
      name: 'Test Hub',
      slug: 'test-hub',
      channel_type: 'hub',
      patchwork_collection_id: @collection.id,
      patchwork_community_type_id: @community_type.id
    )
    assert community.valid?
    assert_equal @collection.id, community.patchwork_collection_id
  end

  test "non-hub community requires collection" do
    community = Community.new(
      name: 'Test Channel',
      slug: 'test-channel',
      channel_type: 'channel',
      patchwork_community_type_id: @community_type.id
    )
    assert_not community.valid?
    assert_includes community.errors[:patchwork_collection_id], "is required for non-hub communities"
  end

  test "non-hub community requires community type" do
    community = Community.new(
      name: 'Test Channel',
      slug: 'test-channel',
      channel_type: 'channel',
      patchwork_collection_id: @collection.id
    )
    assert_not community.valid?
    assert_includes community.errors[:patchwork_community_type_id], "is required for non-hub communities"
  end

  test "valid non-hub community with all required fields" do
    community = Community.new(
      name: 'Test Channel',
      slug: 'test-channel',
      channel_type: 'channel',
      patchwork_collection_id: @collection.id,
      patchwork_community_type_id: @community_type.id
    )
    
    assert community.valid?, "Non-hub community should be valid with all required fields"
  end

  test "valid hub community with optional fields" do
    community = Community.new(
      name: 'Test Hub',
      slug: 'test-hub',
      channel_type: 'hub',
      patchwork_collection_id: @collection.id,
      patchwork_community_type_id: @community_type.id
    )
    
    assert community.valid?, "Hub community should be valid with optional fields"
  end

  test "channel_type must be one of the defined types" do
    unique_id = SecureRandom.uuid[0..7]
    community = Community.new(
      name: "Test Community #{unique_id}",
      slug: "test-community-#{unique_id}",
      channel_type: 'channel',
      patchwork_collection_id: @collection.id,
      patchwork_community_type_id: @community_type.id
    )
    assert community.valid?, "Community should be valid with a valid channel type. Errors: \\#{community.errors.full_messages.join(', ')}"
    
    # Test that only defined types are allowed
    assert_includes Community.channel_types.keys, 'channel'
    assert_includes Community.channel_types.keys, 'channel_feed'
    assert_includes Community.channel_types.keys, 'hub'
    assert_not_includes Community.channel_types.keys, 'invalid'
  end

  # Type Check Tests
  test "hub? returns true for hub communities" do
    community = create_test_community(type: 'hub')
    assert community.hub?
  end

  test "channel? returns true for channel communities" do
    community = create_test_community(type: 'channel')
    assert community.channel?
  end

  test "channel_feed? returns true for channel feed communities" do
    community = create_test_community(type: 'channel_feed')
    assert community.channel_feed?
  end

  # Scope Tests
  test "recommended scope returns recommended communities" do
    community = create_test_community
    community.update!(
      is_recommended: true,
      visibility: :public_access  # Add visibility to pass exclude_incomplete_channels
    )
    assert_includes Community.recommended, community
  end

  test "filter_channels scope returns only channel type communities" do
    channel = create_test_community(type: 'channel')
    hub = create_test_community(type: 'hub')
    assert_includes Community.filter_channels, channel
    assert_not_includes Community.filter_channels, hub
  end

  test "ordered_pos_name scope orders by position and name" do
    community1 = create_test_community(name: 'A Community', position: 2, slug: 'test-community-a')
    community2 = create_test_community(name: 'B Community', position: 1, slug: 'test-community-b')
    ordered = Community.where.not(id: 1).ordered_pos_name
    assert_equal [community2, community1], ordered.to_a
  end

  # Association Tests
  test "has many community links" do
    community = create_test_community
    link = community.patchwork_community_links.create!(
      name: 'Test Link',
      url: 'https://example.com',
      is_social: true
    )
    assert_includes community.patchwork_community_links, link
  end

  test "has many community rules" do
    community = create_test_community
    rule = community.patchwork_community_rules.create!(
      rule: 'Test Rule'
    )
    assert_includes community.patchwork_community_rules, rule
  end

  test "has many community filter keywords" do
    community = create_test_community
    keyword = community.patchwork_community_filter_keywords.create!(
      keyword: 'test',
      filter_type: 'filter_in'
    )
    assert_includes community.patchwork_community_filter_keywords, keyword
  end

  test "has many community hashtags" do
    community = create_test_community
    hashtag = community.patchwork_community_hashtags.create!(
      hashtag: '#test'
    )
    assert_includes community.patchwork_community_hashtags, hashtag
  end

  # Registration Mode Tests
  test "validates registration mode inclusion" do
    community = Community.new(
      name: 'Test Community',
      slug: 'test-community',
      channel_type: 'channel',
      registration_mode: 'invalid_mode'
    )
    assert_not community.valid?
    assert_includes community.errors[:registration_mode], "is not included in the list"
  end

  test "accepts valid registration modes" do
    ['open', 'approved', 'none'].each do |mode|
      unique_id = SecureRandom.uuid[0..7]
      community = Community.new(
        name: "Test Community #{unique_id}",
        slug: "test-community-#{unique_id}",
        channel_type: 'channel',
        registration_mode: mode,
        patchwork_collection_id: @collection.id,
        patchwork_community_type_id: @community_type.id
      )
      assert community.valid?, "Should be valid with registration_mode: #{mode}. Errors: #{community.errors.full_messages.join(', ')}"
    end
  end
end 