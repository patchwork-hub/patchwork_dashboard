require "test_helper"

class DeleteCommunityInstanceServiceTest < ActiveSupport::TestCase
  test "applies connect and read deadlines to the lambda request" do
    service = DeleteCommunityInstanceService.new
    service.instance_variable_set(:@payload, "{}")
    request_options = nil

    HTTParty.stub(:post, ->(_url, options) { request_options = options }) do
      service.send(:invoke_lambda)
    end

    assert_equal DeleteCommunityInstanceService::OPEN_TIMEOUT, request_options[:open_timeout]
    assert_equal DeleteCommunityInstanceService::READ_TIMEOUT, request_options[:read_timeout]
  end
end