require 'test_helper'

class MonitoringControllerTest < ActionDispatch::IntegrationTest
  test 'benchmark endpoint is public and returns timing data' do
    get '/monitoring/benchmark', params: { iterations: 10 }

    assert_response :success
    json = JSON.parse(response.body)
    assert json['ok']
    assert json['iterations'] == 10
    assert json['elapsed_seconds'].is_a?(Numeric)
  end
end
