require "test_helper"
require "minitest/mock"

class JoinedWorkingGroupsControllerTest < ActiveSupport::TestCase
  setup do
    @controller = Api::V1::JoinedWorkingGroupsController.new
    @controller.params = ActionController::Parameters.new(id: "unmapped-group")
    user = Struct.new(:email).new("member@example.test")
    @controller.instance_variable_set(:@account, Struct.new(:user).new(user))
  end

  test "unmapped groups reach the service so staff can join" do
    result = CivicrmMembershipCheckService::Result.new(valid?: true, values_present: true)
    check_eligibility("New working group", expected_id: nil, result: result) do
      @controller.stub(:render_membership_not_eligible, -> { flunk "Eligible staff was rejected" }) do
        @controller.send(:ensure_civicrm_membership_eligibility!)
      end
    end
  end

  test "unmapped groups still reject non-staff" do
    result = CivicrmMembershipCheckService::Result.new(valid?: false, values_present: false)
    rejected = false
    check_eligibility("New working group", expected_id: nil, result: result) do
      @controller.stub(:render_membership_not_eligible, -> { rejected = true }) do
        @controller.send(:ensure_civicrm_membership_eligibility!)
      end
    end
    assert rejected
  end

  test "mapped groups keep passing the requested group ID with a forced remote check" do
    result = CivicrmMembershipCheckService::Result.new(valid?: true, values_present: true)
    check_eligibility("Atlas", expected_id: 20, result: result) do
      @controller.stub(:render_membership_not_eligible, -> { flunk "Eligible member was rejected" }) do
        @controller.send(:ensure_civicrm_membership_eligibility!)
      end
    end
  end

  private

  def check_eligibility(name, expected_id:, result:)
    community = Struct.new(:name).new(name)
    service = Minitest::Mock.new
    service.expect(:call, result)
    @controller.stub(:find_patchwork_community, community) do
      CivicrmMembershipCheckService.stub(:new, lambda { |email, working_group_id:, force_remote:|
        assert_equal "member@example.test", email
        expected_id.nil? ? assert_nil(working_group_id) : assert_equal(expected_id, working_group_id)
        assert_equal true, force_remote
        service
      }) { yield }
    end
    service.verify
  end
end
