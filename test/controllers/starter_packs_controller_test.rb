require 'test_helper'
require 'minitest/mock'

class StarterPacksControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @throttling_enabled = Rack::Attack.enabled
    Rack::Attack.enabled = false
    @creator = Account.create!(username: 'packcreator', display_name: 'Creator', domain: 'example.org', avatar_remote_url: 'https://example.org/avatar.png')
    @member = Account.create!(username: 'packmember', display_name: 'Member', domain: 'example.org', avatar_remote_url: 'https://example.org/avatar.png')
    role = UserRole.create!(name: 'Pack manager', permissions: UserRole::FLAGS[:manage_starter_packs])
    @user = User.create!(email: 'packmanager@example.test', account: @creator, role: role, password: 'test-password-only', agreement: true)
    sign_in @user
    @pack = StarterPack.create!(title: 'Example', instance_name: 'twt')
  end

  teardown do
    Rack::Attack.enabled = @throttling_enabled
  end

  test 'CRUD assigns a searched account independently of signed in user' do
    get starter_packs_path
    assert_response :success
    get new_starter_pack_path
    assert_response :success
    assert_difference('StarterPack.count') do
      post starter_packs_path, params: { starter_pack: { title: 'Remote creator', instance_name: 'Find Out', created_by_id: @member.id.to_s } }
    end
    pack = StarterPack.order(:id).last
    assert_equal @member, pack.created_by
    assert_equal 'findout', pack.instance_name
    get starter_pack_path(pack)
    assert_response :success
    get edit_starter_pack_path(pack)
    assert_response :success
    patch starter_pack_path(pack), params: { starter_pack: { title: 'Updated', created_by_id: @creator.id.to_s } }
    assert_equal 'Updated', pack.reload.title
    assert_equal @creator, pack.created_by
    assert_difference('StarterPack.count', -1) { delete starter_pack_path(pack) }
  end

  test 'members can be added once, reordered and removed' do
    2.times { post add_account_starter_pack_path(@pack), params: { account_id: @member.id }, as: :json }
    assert_response :no_content
    assert_equal 1, @pack.starter_pack_accounts.count
    post add_account_starter_pack_path(@pack), params: { account_id: @creator.id }, as: :json
    ids = @pack.starter_pack_accounts.pluck(:id).reverse.map(&:to_s)
    patch reorder_accounts_starter_pack_path(@pack), params: { ids: ids }, as: :json
    assert_response :no_content
    assert_equal ids, @pack.starter_pack_accounts.reload.pluck(:id).map(&:to_s)
    patch reorder_accounts_starter_pack_path(@pack), params: { ids: [ids.first, ids.first] }, as: :json
    assert_response :unprocessable_entity
    delete remove_account_starter_pack_path(@pack), params: { account_id: @member.id }, as: :json
    assert_response :no_content
    assert_equal [@creator], @pack.accounts.reload.to_a
  end

  test 'pack ordering is isolated to its instance' do
    other = StarterPack.create!(title: 'Other', instance_name: 'findout')
    patch reorder_starter_packs_path, params: { instance_name: 'twt', ids: [other.id.to_s] }, as: :json
    assert_response :unprocessable_entity
    assert_equal 1, other.reload.position
    second = StarterPack.create!(title: 'Second', instance_name: 'twt')
    patch reorder_starter_packs_path, params: { instance_name: 'twt', ids: [second.id.to_s, @pack.id.to_s] }, as: :json
    assert_response :no_content
    assert_equal [second.id, @pack.id], StarterPack.for_instance('twt').ordered.pluck(:id)
    assert_equal [1, 2], StarterPack.for_instance('twt').ordered.pluck(:position)
  end

  test 'new form suggests the next display order for its instance' do
    StarterPack.create!(title: 'Second', instance_name: 'twt', position: 2)
    get new_starter_pack_path
    assert_response :success
    assert_select '#starter_pack_position[value="3"][data-preview-url]:not([disabled]):not([readonly])'
    get next_position_starter_packs_path, as: :json
    assert_equal 3, response.parsed_body.fetch('position')
    get new_starter_pack_path, params: { instance_name: 'twt' }
    assert_select '#starter_pack_position[value="3"]'
    get next_position_starter_packs_path, params: { instance_name: 'T W T' }, as: :json
    assert_response :success
    assert_equal 3, response.parsed_body.fetch('position')
    get next_position_starter_packs_path, params: { instance_name: 'newinstance' }, as: :json
    assert_equal 1, response.parsed_body.fetch('position')
    @pack.update!(position: 7)
    get next_position_starter_packs_path, params: { instance_name: 'twt' }, as: :json
    assert_equal 8, response.parsed_body.fetch('position')
    get edit_starter_pack_path(@pack)
    assert_select '#starter_pack_position[value="7"]:not([data-preview-url])'
  end

  test 'display order can be edited through form submissions' do
    get new_starter_pack_path
    assert_select '#starter_pack_position:not([disabled]):not([readonly])'
    post starter_packs_path, params: { starter_pack: { title: 'Manual order', instance_name: 'twt', position: 5 } }
    assert_response :redirect
    created = StarterPack.order(:id).last
    assert_equal 5, created.position
    patch starter_pack_path(created), params: { starter_pack: { position: 7 } }
    assert_response :redirect
    assert_equal 7, created.reload.position
    patch starter_pack_path(created), params: { starter_pack: { position: @pack.position } }
    assert_response :unprocessable_entity
    assert_equal 7, created.reload.position
    get edit_starter_pack_path(created)
    assert_select '#starter_pack_position:not([disabled]):not([readonly])[value="7"]'
  end

  test 'search works before a pack exists' do
    service = Object.new
    service.define_singleton_method(:call) { [{ id: '123', acct: 'example@remote.test' }] }
    StarterPackAccountSearchService.stub(:new, ->(*) { service }) do
      get search_accounts_starter_packs_path, params: { query: '@example@remote.test' }, as: :json
      assert_response :success
      assert_equal '123', response.parsed_body.fetch('accounts').first.fetch('id')
    end
  end

  test 'users without permission cannot search or mutate packs' do
    @user.update!(role: UserRole.create!(name: 'Reader', permissions: 0))
    get next_position_starter_packs_path, params: { instance_name: 'twt' }, as: :json
    assert_response :forbidden
    get search_accounts_starter_packs_path, params: { query: 'example' }, as: :json
    assert_response :forbidden
    post add_account_starter_pack_path(@pack), params: { account_id: @member.id }, as: :json
    assert_response :forbidden
    delete starter_pack_path(@pack), as: :json
    assert_response :forbidden
    assert StarterPack.exists?(@pack.id)
  end
end