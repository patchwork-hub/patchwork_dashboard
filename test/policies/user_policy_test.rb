require 'test_helper'

class UserPolicyTest < ActiveSupport::TestCase
  def test_scope
  end

  def test_show
  end

  def test_create
  end

  def test_update
  end

  def test_destroy
  end

  def test_login_allows_active_community_admin
    user = user_without_dashboard_access

    CommunityAdmin.stub(:exists?, true) do
      assert UserPolicy.new(user, user).login?
    end
  end

  def test_login_rejects_inactive_community_admin
    user = user_without_dashboard_access

    CommunityAdmin.stub(:exists?, false) do
      refute UserPolicy.new(user, user).login?
    end
  end

  private

  def user_without_dashboard_access
    Struct.new(:account_id) do
      def master_admin?
        false
      end

      def role
        UserRole.nobody
      end
    end.new(123)
  end
end
