require "test_helper"

class ApiPaginationTest < ActionDispatch::IntegrationTest
  test "accounts preserve the default page size when pagination params are missing" do
    get api_v1_accounts_url, headers: api_key_headers

    assert_response :success
    assert_equal 50, response.parsed_body.dig("meta", "per_page")
  end

  test "accounts cap an explicitly requested page size" do
    get api_v1_accounts_url, params: { per_page: 10_000 }, headers: api_key_headers

    assert_response :success
    assert_operator response.parsed_body.fetch("data").size, :<=, 100
    assert_equal 100, response.parsed_body.dig("meta", "per_page")
  end

  test "collections remain unpaginated when pagination params are missing" do
    get api_v1_collections_url

    assert_response :success
    assert_not response.parsed_body.key?("meta")
  end

  test "collections include metadata when pagination is requested" do
    get api_v1_collections_url, params: { page: 1, per_page: 2 }

    assert_response :success
    assert_operator response.parsed_body.fetch("data").size, :<=, 2
    assert_equal 1, response.parsed_body.dig("meta", "current_page")
    assert_equal 2, response.parsed_body.dig("meta", "per_page")
  end

  test "channels remain unpaginated when pagination params are missing" do
    get recommend_channels_api_v1_channels_url

    assert_response :success
    assert_not response.parsed_body.key?("meta")
  end

  test "channels cap requested pagination and include metadata" do
    get recommend_channels_api_v1_channels_url, params: { page: 0, per_page: 10_000 }

    assert_response :success
    assert_operator response.parsed_body.fetch("data").size, :<=, 100
    assert_equal 1, response.parsed_body.dig("meta", "current_page")
    assert_equal 100, response.parsed_body.dig("meta", "per_page")
  end

  private

  def api_key_headers
    api_key = api_keys(:one)
    { "x-api-key" => api_key.key, "x-api-secret" => api_key.secret }
  end
end