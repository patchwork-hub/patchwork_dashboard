require 'test_helper'

class CommunityPolicyTest < ActiveSupport::TestCase
  def setup
    setup_common_data
  end

  # Index Tests
  test "master admin can view index" do
    assert CommunityPolicy.new(@master_admin, Community).index?
  end

  test "hub admin can view index" do
    assert CommunityPolicy.new(@hub_admin, Community).index?
  end

  test "org admin can view index" do
    assert CommunityPolicy.new(@org_admin, Community).index?
  end

  # Show Tests
  test "master admin can view any community" do
    community = create_test_community
    assert CommunityPolicy.new(@master_admin, community).show?
  end

  test "hub admin can view communities in their hub" do
    community = create_test_community(user: @hub_admin)
    assert CommunityPolicy.new(@hub_admin, community).show?
  end

  test "org admin can view communities in their organization" do
    community = create_test_community(user: @org_admin)
    assert CommunityPolicy.new(@org_admin, community).show?
  end

  test "org admin cannot view communities outside their organization" do
    community = create_test_community(user: @hub_admin)
    assert_not CommunityPolicy.new(@org_admin, community).show?
  end

  # Create Tests
  test "master admin can create any community" do
    assert CommunityPolicy.new(@master_admin, Community).create?
  end

  test "hub admin can create communities in their hub" do
    assert CommunityPolicy.new(@hub_admin, Community).create?
  end

  test "org admin cannot create communities" do
    assert_not CommunityPolicy.new(@org_admin, Community).create?
  end

  # Update Tests
  test "master admin can update any community" do
    community = create_test_community
    assert CommunityPolicy.new(@master_admin, community).update?
  end

  test "hub admin can update communities in their hub" do
    community = create_test_community(user: @hub_admin)
    assert CommunityPolicy.new(@hub_admin, community).update?
  end

  test "org admin can update their own communities" do
    community = create_test_community(user: @org_admin)
    assert CommunityPolicy.new(@org_admin, community).update?
  end

  test "org admin cannot update other communities" do
    community = create_test_community(user: @hub_admin)
    assert_not CommunityPolicy.new(@org_admin, community).update?
  end

  # Destroy Tests
  test "master admin can destroy any community" do
    community = create_test_community
    assert CommunityPolicy.new(@master_admin, community).destroy?
  end

  test "hub admin can destroy communities in their hub" do
    community = create_test_community(user: @hub_admin)
    assert CommunityPolicy.new(@hub_admin, community).destroy?
  end

  test "org admin cannot destroy communities" do
    community = create_test_community(user: @org_admin)
    assert_not CommunityPolicy.new(@org_admin, community).destroy?
  end

  # Scope Tests
  test "master admin can see all communities" do
    create_test_community(user: @master_admin)
    create_test_community(user: @hub_admin)
    create_test_community(user: @org_admin)
    
    communities = CommunityPolicy::Scope.new(@master_admin, Community).resolve
    assert_equal 3, communities.count
  end

  test "hub admin can see communities in their hub" do
    create_test_community(user: @hub_admin)
    create_test_community(user: @org_admin)
    
    communities = CommunityPolicy::Scope.new(@hub_admin, Community).resolve
    assert_equal 1, communities.count
  end

  test "org admin can see their own communities" do
    create_test_community(user: @org_admin)
    create_test_community(user: @hub_admin)
    
    communities = CommunityPolicy::Scope.new(@org_admin, Community).resolve
    assert_equal 1, communities.count
  end

  # Additional Permission Tests
  test "master admin can manage community settings" do
    community = create_test_community
    assert CommunityPolicy.new(@master_admin, community).manage_settings?
  end

  test "hub admin can manage settings for their communities" do
    community = create_test_community(user: @hub_admin)
    assert CommunityPolicy.new(@hub_admin, community).manage_settings?
  end

  test "org admin cannot manage community settings" do
    community = create_test_community(user: @org_admin)
    assert_not CommunityPolicy.new(@org_admin, community).manage_settings?
  end

  test "master admin can manage community members" do
    community = create_test_community
    assert CommunityPolicy.new(@master_admin, community).manage_members?
  end

  test "hub admin can manage members for their communities" do
    community = create_test_community(user: @hub_admin)
    assert CommunityPolicy.new(@hub_admin, community).manage_members?
  end

  test "org admin can manage members for their communities" do
    community = create_test_community(user: @org_admin)
    assert CommunityPolicy.new(@org_admin, community).manage_members?
  end

  test "org admin cannot manage members for other communities" do
    community = create_test_community(user: @hub_admin)
    assert_not CommunityPolicy.new(@org_admin, community).manage_members?
  end
end
