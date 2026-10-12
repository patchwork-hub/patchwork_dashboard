require "test_helper"

class ContributorSearchServiceTest < ActiveSupport::TestCase
  test "returns after the local account lookup reaches its retry limit" do
    lookup_count = 0
    sleep_count = 0
    service = ContributorSearchService.new("example")

    Account.stub(:where, lambda { |*|
      lookup_count += 1
      []
    }) do
      service.stub(:sleep, ->(_delay) { sleep_count += 1 }) do
        result = service.send(
          :find_saved_accounts_with_retry,
          [{ "username" => "missing-account" }]
        )

        assert_empty result
      end
    end

    assert_equal ContributorSearchService::MAX_LOCAL_LOOKUP_ATTEMPTS, lookup_count
    assert_equal ContributorSearchService::MAX_LOCAL_LOOKUP_ATTEMPTS - 1, sleep_count
  end
end