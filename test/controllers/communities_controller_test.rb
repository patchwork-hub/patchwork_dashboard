require 'test_helper'

class CommunitiesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  # include FactoryBot::Syntax::Methods

  def setup
    setup_common_data
    sign_in @master_admin
  end

  # Index Action Tests
  test "should get index" do
    get communities_path, params: { channel_type: 'channel' }
    assert_response :success
    assert_not_nil assigns(:records)
  end

  test "should filter communities by type" do
    create_test_community(channel_type: 'hub', name: 'Hub Community', slug: 'hub-community')
    create_test_community(channel_type: 'channel', name: 'Channel Community', slug: 'channel-community')
    
    get communities_path, params: { channel_type: 'hub' }
    assert_response :success
    assert_equal 1, assigns(:records).count
    assert_equal 'hub', assigns(:records).first.channel_type
  end

  test "should search communities by name" do
    first_community = create_test_community
    second_community = create_test_community
    
    get communities_path, params: { q: { name_cont: first_community.name }, channel_type: 'channel' }
    assert_response :success
    assert_equal 1, assigns(:records).count
    assert_equal first_community.name, assigns(:records).first.name
  end

  # Show Action Tests
  test "should show community" do
    community = create_test_community
    get "/channels/step0", params: { id: community.id }
    assert_response :success
    assert_equal community, assigns(:community)
  end

  # test "should show community with posts" do
  #   community = create_test_community
  #   post = Post.create!(
  #     community: community,
  #     content: "Test post content",
  #     account: create_test_account(@master_admin)
  #   )
    
  #   get "/channels/step0", params: { id: community.id }
  #   assert_response :success
  #   assert_includes assigns(:posts), post
  # end

  # New Action Tests
  test "should get new" do
    get step0_new_communities_path, params: { content_type: 'broadcast_channel' }
    assert_response :success
    assert_not_nil assigns(:content_type)
  end

  test "should get new with collection context" do
    get step0_new_communities_path, params: { 
      collection_id: @collection.id,
      content_type: 'broadcast_channel'
    }
    assert_response :success
    assert_not_nil assigns(:content_type)
  end

  # Create Action Tests
  test "should create hub community" do
    assert_difference('Community.count') do
      post "/channels/step1", params: {
        channel_type: 'hub',
        content_type: 'broadcast_channel',
        form_community: {
          name: 'New Hub',
          slug: 'new-hub',
          channel_type: 'hub',
          bio: 'Test hub description',
          community_type_id: @community_type.id
        }
      }
    end
    
    assert_redirected_to "/channels/#{Community.last.id}/step2?channel_type=hub"
    assert_equal 'New Hub', Community.last.name
    assert_equal 'hub', Community.last.channel_type
  end

  test "should create non-hub community" do
    assert_difference('Community.count') do
      post "/channels/step1", params: {
        channel_type: 'channel',
        content_type: 'custom_channel',
        form_community: {
          name: 'New Channel',
          slug: 'new-channel',
          channel_type: 'channel',
          collection_id: @collection.id,
          community_type_id: @community_type.id,
          bio: 'Test channel description'
        }
      }
    end
    
    assert_redirected_to "/channels/#{Community.last.id}/step2?channel_type=channel"
    assert_equal 'New Channel', Community.last.name
    assert_equal 'channel', Community.last.channel_type
  end

  test "should not create community with invalid params" do
    assert_no_difference('Community.count') do
      post "/channels/step1", params: {
        channel_type: 'channel',
        content_type: 'custom_channel',
        form_community: {
          name: '',
          slug: '',
          channel_type: 'invalid'
        }
      }
    end
    
    assert_response :unprocessable_entity
  end

  # Edit Action Tests
  test "should get edit" do
    community = create_test_community
    get "/channels/#{community.id}/step2", params: { channel_type: community.channel_type }
    assert_response :success
    assert_equal community, assigns(:community)
  end

  # Update Action Tests
  test "should update community" do
    community = create_test_community
    post "/channels/#{community.id}/manage_additional_information", params: {
      channel_type: community.channel_type,
      community: {
        patchwork_community_additional_informations_attributes: [
          {
            heading: "Additional Information",
            text: "Updated description"
          }
        ]
      }
    }
    
    assert_response :success
    community.reload
    assert_equal "Updated description", community.patchwork_community_additional_informations.first.text
  end

  test "should not update community with invalid params" do
    community = create_test_community
    post "/channels/#{community.id}/manage_additional_information", params: {
      channel_type: community.channel_type,
      community: {
        patchwork_community_additional_informations_attributes: [
          {
            heading: "",
            text: ""
          }
        ]
      }
    }
    
    assert_redirected_to "/channels/#{community.id}/step6"
    assert_not_empty flash[:error]
  end

  # Destroy Action Tests
  test "should destroy community" do
    community = create_test_community
    assert_not community.deleted?
    
    delete "/channels/#{community.id}", params: { channel_type_param: community.channel_type }
    
    assert_redirected_to "/channels?channel_type=#{community.channel_type}"
    community.reload
    assert community.deleted?
  end

  # Authorization Tests
  test "should not allow non-admin to create community" do
    sign_in @org_admin
    assert_no_difference('Community.count') do
      post "/channels/step1", params: {
        channel_type: 'hub',
        content_type: 'broadcast_channel',
        form_community: {
          name: 'New Community',
          slug: 'new-community',
          channel_type: 'hub',
          bio: 'Test description',
          community_type_id: @community_type.id
        }
      }
    end
    
    assert_response :forbidden
  end

  test "should not allow non-admin to update community" do
    community = create_test_community
    sign_in @org_admin
    
    post "/channels/#{community.id}/manage_additional_information", params: {
      channel_type: community.channel_type,
      community: {
        patchwork_community_additional_informations_attributes: [
          {
            heading: "Additional Information",
            text: "Updated description"
          }
        ]
      }
    }
    
    assert_response :forbidden
    community.reload
    assert_not_equal "Updated description", community.patchwork_community_additional_informations.first&.text
  end

  test "should not allow non-admin to destroy community" do
    community = create_test_community
    sign_in @org_admin
    
    assert_no_difference('Community.count') do
      delete "/channels/#{community.id}", params: { channel_type_param: community.channel_type }
    end
    
    assert_response :forbidden
    community.reload
    assert_not community.deleted?
  end

  # Additional Feature Tests
  # test "should toggle community status" do
  #   community = create_test_community
  #   patch toggle_status_community_path(community)
    
  #   assert_response :success
  #   community.reload
  #   assert_not community.active?
  # end

  # test "should update community position" do
  #   community1 = create_test_community(position: 1)
  #   community2 = create_test_community(position: 2)
    
  #   patch "/channels/#{community1.id}/update_position", params: {
  #     position: 2
  #   }
    
  #   assert_response :success
  #   community1.reload
  #   community2.reload
  #   assert_equal 2, community1.position
  #   assert_equal 1, community2.position
  # end

  # Visibility Update Tests
  test "should update visibility for channel community" do
    community = create_test_community(channel_type: 'channel')
    
    post "/channels/#{community.id}/set_visibility", params: {
      community: { visibility: 'private_local' }
    }
    
    assert_redirected_to communities_path(channel_type: 'channel')
    community.reload
    assert_equal 'private_local', community.visibility
  end

  test "should update visibility for hub community" do
    community = create_test_community(channel_type: 'hub')
    
    post "/channels/#{community.id}/set_visibility", params: {
      community: { visibility: 'guest_access' }
    }
    
    assert_redirected_to communities_path(channel_type: 'hub')
    community.reload
    assert_equal 'guest_access', community.visibility
  end

  test "should update visibility for channel feed community" do
    community = create_test_community(channel_type: 'channel_feed')
    
    post "/channels/#{community.id}/set_visibility", params: {
      community: { visibility: 'public_access' }
    }
    
    assert_redirected_to communities_path(channel_type: 'channel_feed')
    community.reload
    assert_equal 'public_access', community.visibility
  end

  test "should use default visibility when not provided" do
    community = create_test_community(channel_type: 'channel')
    
    post "/channels/#{community.id}/set_visibility", params: {
      community: { visibility: '' }
    }
    
    assert_redirected_to communities_path(channel_type: 'channel')
    community.reload
    assert_equal 'public_access', community.visibility
  end

  test "should handle failed visibility update for channel" do
    community = create_test_community(channel_type: 'channel')
    admin = create_test_account(@master_admin)
    
    # Create the community admin record
    CommunityAdmin.create!(
      patchwork_community_id: community.id,
      account_id: admin.id,
      role: 'OrganisationAdmin',
      account_status: 0,
      email: admin.user.email,
      username: admin.username,
      display_name: admin.display_name
    )

    # Simulate a failed update by adding a validation error
    def community.update(*)
      errors.add(:base, "Forced update error")
      false
    end

    # Store the original methods
    original_find = Community.method(:find)
    original_account_find = Account.method(:find_by)

    # Override the find methods temporarily
    Community.define_singleton_method(:find) do |id|
      id.to_i == community.id ? community : original_find.call(id)
    end

    Account.define_singleton_method(:find_by) do |args|
      args[:id] == admin.id ? admin : original_account_find.call(args)
    end

    post "/channels/#{community.id}/set_visibility", params: {
      community: { visibility: 'public_access' }
    }

    assert_response :unprocessable_entity
    assert_template :step6

    # Restore the original methods
    Community.define_singleton_method(:find, original_find)
    Account.define_singleton_method(:find_by, original_account_find)
  end

  test "should handle failed visibility update for hub" do
    community = create_test_community(channel_type: 'hub')
    admin = create_test_account(@master_admin)
    
    # Create the community admin record
    CommunityAdmin.create!(
      patchwork_community_id: community.id,
      account_id: admin.id,
      role: 'OrganisationAdmin',
      account_status: 0,
      email: admin.user.email,
      username: admin.username,
      display_name: admin.display_name
    )

    # Simulate a failed update by adding a validation error
    def community.update(*)
      errors.add(:base, "Forced update error")
      false
    end

    # Store the original methods
    original_find = Community.method(:find)
    original_account_find = Account.method(:find_by)

    # Override the find methods temporarily
    Community.define_singleton_method(:find) do |id|
      id.to_i == community.id ? community : original_find.call(id)
    end

    Account.define_singleton_method(:find_by) do |args|
      args[:id] == admin.id ? admin : original_account_find.call(args)
    end

    post "/channels/#{community.id}/set_visibility", params: {
      community: { visibility: 'public_access' }
    }

    assert_response :unprocessable_entity
    assert_template :step4

    # Restore the original methods
    Community.define_singleton_method(:find, original_find)
    Account.define_singleton_method(:find_by, original_account_find)
  end
end 