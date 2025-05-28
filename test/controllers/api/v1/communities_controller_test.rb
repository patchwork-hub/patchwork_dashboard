require 'test_helper'

class Api::V1::CommunitiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @user_role = UserRole.create!(name: 'OrganisationAdmin')
    @user.update!(role: @user_role)
    @account = accounts(:one)
    @community = communities(:one)
    @collection = collections(:test_collection)
    @community_type = community_types(:test_type)
    
    # Create a valid IP address
    @ip_address = IpAddress.create!(
      ip: '192.168.1.1',
      use_count: 0
    )
    
    # Associate the IP address with the community
    @community.update!(ip_address_id: @ip_address.id)
    
    # Create a CommunityAdmin record for the test user
    CommunityAdmin.create!(
      account_id: @account.id,
      patchwork_community_id: @community.id,
      email: 'test@example.com',
      username: 'testuser',
      role: 'OrganisationAdmin',
      account_status: 0,
      is_boost_bot: true
    )
    
    # Create a valid token for testing
    token = 'test_token_123'
    @headers = { 'Authorization' => "Bearer #{token}" }
    
    # Skip authentication for tests
    Api::V1::CommunitiesController.skip_before_action :authenticate_user_from_header
    
    # Set current_user for all requests
    Api::V1::CommunitiesController.any_instance.stubs(:current_user).returns(@user)

    # Stub environment variables
    ENV['MASTODON_INSTANCE_URL'] = 'https://test.mastodon.instance'
  end

  test "should get index" do
    get api_v1_communities_url, headers: @headers
    assert_response :success
    assert_match 'data', @response.body
  end

  test "should create community if not already created" do
    CommunityAdmin.where(account_id: @account.id).delete_all
    params = {
      name: 'New Channel',
      slug: 'new-channel',
      collection_id: @collection.id,
      channel_type: 'channel'
    }

    post api_v1_communities_url, params: params, headers: @headers
    assert_response :created
    assert_match 'community', @response.body
  end

  test "should not create community if one already exists" do
    post api_v1_communities_url, params: { 
      name: 'Duplicate Channel',
      collection_id: @collection.id,
      channel_type: 'channel'
    }, headers: @headers
    assert_response :forbidden
    assert_includes @response.body, "You can only create one channel"
  end

  test "should show community" do
    get api_v1_community_url(@community), headers: @headers
    assert_response :success
    assert_match @community.name, @response.body
  end

  test "should update community" do
    community = create_test_community
    patch api_v1_community_url(community), params: { 
      name: "Updated Name",
      collection_id: @collection.id,
        community_type_id: @community_type.id,
        bio: "Updated description"
    }, headers: @headers
    assert_response :success
    @community.reload
    assert_equal "Updated Name", community.name
  end

  test "should return community types" do
    get community_types_api_v1_communities_url, headers: @headers
    assert_response :success
    assert_match 'community_types', @response.body
  end

  test "should return collections" do
    get collections_api_v1_communities_url, headers: @headers
    assert_response :success
    assert_match 'collections', @response.body
  end

  test "should return bad request if query/token is missing in search_contributor" do
    get search_contributor_api_v1_communities_url, headers: @headers
    assert_response :bad_request
    assert_match 'required', @response.body
  end

  test "should return error for missing patchwork_community_id in contributor_list" do
    get contributor_list_api_v1_communities_url, headers: @headers
    assert_response :bad_request
    assert_match 'patchwork_community_id is required', @response.body
  end

  test "should set visibility" do
    post set_visibility_api_v1_communities_url, params: { id: @community.id }, headers: @headers
    assert_response :ok
    assert_match 'successfully', @response.body
  end

  test "should manage additional information" do
    patch manage_additional_information_api_v1_community_url(@community),
         params: { 
           community: { 
             registration_mode: 'open',
             patchwork_collection_id: @collection.id,
             patchwork_community_type_id: @community_type.id,
             channel_type: 'channel'
           } 
         },
         headers: @headers
    assert_response :success
  end

  test "should fetch ip address" do
    get fetch_ip_address_api_v1_communities_url(id: @community.id), headers: @headers
    assert_response :success
    assert_match 'ip_address', @response.body
  end
end