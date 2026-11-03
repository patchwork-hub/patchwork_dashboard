require 'test_helper'

class AutoFollowPolicyTest < ActiveSupport::TestCase
  test 'allows master admins and users with auto-follow permission' do
    manager_role = UserRole.create!(name: 'Auto-follow manager', permissions: UserRole::FLAGS[:manage_auto_follows])
    manager = User.new(role: manager_role)
    policy = AutoFollowPolicy.new(manager, :auto_follow)
    assert policy.index?
    assert policy.create?
    assert policy.update?
    assert policy.destroy?
  end

  test 'denies users without auto-follow permission' do
    reader = User.new(role: UserRole.create!(name: 'Auto-follow reader', permissions: 0))
    refute AutoFollowPolicy.new(reader, :auto_follow).index?
  end
end