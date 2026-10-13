require 'test_helper'

class CommunityPolicyTest < ActiveSupport::TestCase
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

  def test_community_admin_can_access_own_community_only
    user = Struct.new(:account_id) do
      def master_admin?
        false
      end

      def community_admin?
        true
      end
    end.new(123)
    membership = ->(conditions = {}) { conditions[:patchwork_community_id] == 1 }
    own_policy = CommunityPolicy.new(user, Struct.new(:id).new(1))
    other_policy = CommunityPolicy.new(user, Struct.new(:id).new(2))

    CommunityAdmin.stub(:exists?, membership) do
      assert own_policy.initialize_form?
      refute other_policy.initialize_form?
    end
  end
end
