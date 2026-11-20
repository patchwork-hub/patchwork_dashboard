require "test_helper"
require "minitest/mock"

class CivicrmMembershipCheckServiceTest < ActiveSupport::TestCase
  setup do
    @service = CivicrmMembershipCheckService.new("member@example.test", working_group_id: 20, force_remote: true)
  end

  test "staff can join every mapped working group without belonging to it" do
    Api::V1::JoinedWorkingGroupsController::CIVICRM_WORKING_GROUP_IDS_BY_COMMUNITY_NAME.each_value do |group_id|
      service = CivicrmMembershipCheckService.new("member@example.test", working_group_id: group_id, force_remote: true)
      assert check([{ "user_group_ids" => [3, 4], "user_groups" => ["CSIDNet Staff", "Newsletter sign-up"] }], service: service).valid?
    end
  end

  test "staff can join unmapped working groups but non-staff cannot" do
    service = CivicrmMembershipCheckService.new("member@example.test", working_group_id: nil, force_remote: true)
    assert check([{ "user_group_ids" => [3], "user_groups" => ["CSIDNet Staff"] }], service: service).valid?
    refute check([{ "user_group_ids" => [20], "user_groups" => ["Atlas"] }], service: service).valid?
  end

  test "staff requires both the group ID and exact name on the same contact" do
    [
      [{ "user_group_ids" => [3], "user_groups" => ["Other"] }],
      [{ "user_group_ids" => [4], "user_groups" => ["CSIDNet Staff"] }],
      [{ "user_group_ids" => [3] }],
      [{ "user_groups" => ["CSIDNet Staff"] }],
      [{ "user_group_ids" => [3], "user_groups" => ["csidnet staff"] }],
      [{ "user_group_ids" => [3] }, { "user_groups" => ["CSIDNet Staff"] }]
    ].each do |values|
      refute check(values).valid?
    end
  end

  test "non-staff still requires membership of the requested working group" do
    assert check([], membership_values: [{ "user_group_ids" => [20], "user_groups" => ["Atlas"] }]).valid?
    refute check([{ "user_group_ids" => [21], "user_groups" => ["Ethical Framework"] }]).valid?
    refute check([{ "user_groups" => ["Atlas"] }]).valid?
  end

  test "existing group-filtered matches do not require returned group IDs or a staff lookup" do
    requests = []
    result = check(
      [],
      membership_values: [{ "id" => 1, "user_groups" => ["Atlas"] }],
      inspect_request: ->(request) { requests << JSON.parse(request.fetch(:query).fetch(:params)) }
    )

    assert result.valid?
    assert result.values_present
    assert_nil result.error_message
    assert_equal ["Atlas"], result.user_groups
    assert_equal 1, requests.size
    assert_includes requests.first.fetch("where"), ["groups", "IN", [20]]
  end

  test "existing matches remain eligible without returned group labels" do
    result = check([], membership_values: [{ "id" => 1 }])

    assert result.valid?
    assert result.values_present
    assert_empty result.user_groups
  end

  test "supports string arrays and concatenated CiviCRM groups" do
    [
      { "user_group_ids" => ["3", "4"], "user_groups" => ["CSIDNet Staff", "Newsletter sign-up"] },
      { "user_group_ids" => "3,4", "user_groups" => "CSIDNet Staff,Newsletter sign-up" },
      { "user_group_ids" => "3;4", "user_groups" => "CSIDNet Staff;Newsletter sign-up" }
    ].each do |contact|
      assert check([contact]).valid?
    end
  end

  test "lookup preserves the original group filter before checking staff separately" do
    requests = []
    check([], inspect_request: ->(request) { requests << JSON.parse(request.fetch(:query).fetch(:params)) })

    assert_equal 2, requests.size
    assert_includes requests.first.fetch("where"), ["groups", "IN", [20]]
    assert_includes requests.last.fetch("where"), ["groups", "IN", [3]]
    requests.each do |params|
      assert_includes params.fetch("where"), ["email.email", "=", "member@example.test"]
      assert_includes params.fetch("where"), ["is_deleted", "=", false]
      assert_includes params.fetch("join"), ["GroupContact AS group_contact", "LEFT", ["group_contact.status", "=", "'Added'"]]
    end
  end

  test "working group ID parsing preserves comma-separated IDs and ignores invalid input" do
    service = CivicrmMembershipCheckService.new("member@example.test", working_group_id: ["20, 21", "20", "invalid", "22;23"], force_remote: true)
    params = nil
    result = check([], service: service, membership_values: [{ "id" => 1 }],
                       inspect_request: ->(request) { params = JSON.parse(request.fetch(:query).fetch(:params)) })

    assert result.valid?
    assert_includes params.fetch("where"), ["groups", "IN", [20, 21]]
  end

  test "empty malformed and unsuccessful responses deny membership" do
    [[], [nil], ["invalid"], [{}]].each do |values|
      result = check(values)
      refute result.valid?
      refute result.values_present
      assert result.error_message.present?
    end
    refute check([{ "user_group_ids" => [3], "user_groups" => ["CSIDNet Staff"] }], success: false).valid?
  end

  test "forced checks do not bypass the remote lookup for allowlisted accounts" do
    @service.stub(:allowlisted_email?, true) do
      refute check([]).valid?
    end
  end

  test "enabled optional checks preserve the allowlist bypass for existing working groups" do
    service = CivicrmMembershipCheckService.new("member@example.test", working_group_id: 20)
    service.stub(:feature_enabled?, true) do
      service.stub(:allowlisted_email?, true) do
        CivicrmMembershipCheckService.stub(:get, ->(*) { flunk "Unexpected CiviCRM request" }) do
          assert service.call.valid?
        end
      end
    end
  end

  test "failed original lookups deny membership without attempting a staff bypass" do
    requests = []
    result = check(
      [{ "user_group_ids" => [3], "user_groups" => ["CSIDNet Staff"] }],
      success: false,
      inspect_request: ->(request) { requests << request }
    )

    refute result.valid?
    assert_equal 1, requests.size
  end

  test "missing email or configuration denies membership without a remote request" do
    CivicrmMembershipCheckService.stub(:get, ->(*) { flunk "Unexpected CiviCRM request" }) do
      service = CivicrmMembershipCheckService.new("", working_group_id: 20, force_remote: true)
      refute service.call.valid?

      @service.stub(:config_present?, false) do
        refute @service.call.valid?
      end
    end
  end

  test "connection errors deny membership" do
    @service.stub(:config_present?, true) do
      @service.stub(:endpoint_url, "https://crm.example.test") do
        @service.stub(:request_headers, {}) do
          CivicrmMembershipCheckService.stub(:get, ->(*) { raise SocketError, "CiviCRM unavailable" }) do
            refute @service.call.valid?
          end
        end
      end
    end
  end

  test "disabled optional checks preserve the existing bypass" do
    service = CivicrmMembershipCheckService.new("member@example.test", working_group_id: 20)
    service.stub(:feature_enabled?, false) do
      CivicrmMembershipCheckService.stub(:get, ->(*) { flunk "Unexpected CiviCRM request" }) do
        assert service.call.valid?
      end
    end
  end

  private

  def check(values, service: @service, membership_values: [], success: true, inspect_request: nil)
    service.stub(:config_present?, true) do
      service.stub(:endpoint_url, "https://crm.example.test/civicrm/ajax/api4/Contact/get") do
        service.stub(:request_headers, {}) do
          CivicrmMembershipCheckService.stub(:get, lambda { |_url, **request|
            inspect_request&.call(request)
            params = JSON.parse(request.fetch(:query).fetch(:params))
            staff_lookup = params.fetch("where").include?(["groups", "IN", [3]])
            body = { "values" => staff_lookup ? values : membership_values }
            Struct.new(:body, :parsed_response, :code, :success?).new(body.to_json, body, success ? 200 : 503, success)
          }) { service.call }
        end
      end
    end
  end
end
