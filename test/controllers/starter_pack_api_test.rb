require 'test_helper'

class StarterPackApiTest < ActionDispatch::IntegrationTest
  setup do
    @throttling_enabled = Rack::Attack.enabled
    Rack::Attack.enabled = false
    @creator = Account.create!(username: 'packcreator', display_name: 'Creator', domain: 'example.org', uri: 'https://example.org/users/packcreator', avatar_remote_url: 'https://example.org/avatar.png', header_remote_url: 'https://example.org/header.png')
    @member = Account.create!(username: 'packmember', display_name: 'Member', domain: 'example.org', avatar_remote_url: 'https://example.org/avatar.png', header_remote_url: 'https://example.org/header.png')
    @pack = StarterPack.create!(title: 'Example', description: 'Example description', instance_name: 'twt', created_by: @creator)
    @pack.starter_pack_accounts.create!(account: @member, position: 0)
    @pack.starter_pack_accounts.create!(account: @creator, position: 1)
    @other = StarterPack.create!(title: 'Other', instance_name: 'findout')
  end

  teardown do
    Rack::Attack.enabled = @throttling_enabled
  end

  test 'public list defaults to twt and exposes only public account fields' do
    get '/api/v1/channels/starter_packs_channels', as: :json
    assert_response :success
    packs = response.parsed_body.fetch('data')
    assert_equal [@pack.id.to_s], packs.map { |pack| pack.fetch('id') }
    assert_equal %w[collected_by description id title total_accounts], packs.first.keys.sort
    assert_equal 2, packs.first.fetch('total_accounts')
    creator = packs.first.fetch('collected_by')
    assert_equal @creator.id.to_s, creator.fetch('id')
    assert_equal 'packcreator@example.org', creator.fetch('acct')
    %w[email private_key public_key encrypted_password].each { |field| assert_not creator.key?(field) }
  end

  test 'detail uses membership order and string IDs' do
    get "/api/v1/channels/#{@pack.id}/starter_packs_detail", as: :json
    assert_response :success
    assert_equal @pack.id.to_s, response.parsed_body.fetch('channel').fetch('id')
    assert_equal [@member.id.to_s, @creator.id.to_s], response.parsed_body.fetch('followers').map { |account| account.fetch('id') }
  end

  test 'instance names are normalized and detail cannot cross instances' do
    get '/api/v1/channels/starter_packs_channels', params: { starter_pack_source: 'Find Out' }, as: :json
    assert_equal [@other.id.to_s], response.parsed_body.fetch('data').map { |pack| pack.fetch('id') }
    get "/api/v1/channels/#{@pack.id}/starter_packs_detail", params: { starter_pack_source: 'findout' }, as: :json
    assert_response :not_found
    get '/api/v1/channels/0/starter_packs_detail', as: :json
    assert_response :not_found
  end

  test 'unknown instances return no data rather than file fallback' do
    get '/api/v1/channels/starter_packs_channels', params: { starter_pack_source: 'missing' }, as: :json
    assert_equal [], response.parsed_body.fetch('data')
  end

  test 'cached responses reflect membership deletion and creator deletion' do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    get '/api/v1/channels/starter_packs_channels', as: :json
    @member.delete
    @creator.delete
    get '/api/v1/channels/starter_packs_channels', as: :json
    pack = response.parsed_body.fetch('data').first
    assert_equal 0, pack.fetch('total_accounts')
    assert_nil pack.fetch('collected_by')
  ensure
    Rails.cache = original_cache
  end
end