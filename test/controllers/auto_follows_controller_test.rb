require 'test_helper'
require 'minitest/mock'

class AutoFollowsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @throttling_enabled = Rack::Attack.enabled
    Rack::Attack.enabled = false
    @creator = Account.create!(username: 'autofollowmanager', display_name: 'Manager', domain: 'example.org')
    @member = Account.create!(username: 'autofollowmember', display_name: 'Member', domain: 'example.org')
    role = UserRole.create!(name: 'Auto-follow manager', permissions: UserRole::FLAGS[:manage_auto_follows])
    @user = User.create!(email: 'autofollowmanager@example.test', account: @creator, role: role, password: 'test-password-only', agreement: true)
    sign_in @user
    @auto_follow = AutoFollow.create!(title: 'Example', instance_name: 'twt')
  end

  teardown do
    Rack::Attack.enabled = @throttling_enabled
  end

  test 'CRUD normalizes the instance and updates enabled state' do
    get auto_follows_path
    assert_response :success
    get new_auto_follow_path
    assert_response :success
    assert_difference('AutoFollow.count') do
      post auto_follows_path, params: { auto_follow: { title: 'Remote instance', instance_name: 'Toot Wales', enabled: '0' } }
    end
    auto_follow = AutoFollow.order(:id).last
    assert_equal 'tootwales', auto_follow.instance_name
    assert_not auto_follow.enabled?
    post add_account_auto_follow_path(auto_follow), params: { account_id: @member.id }, as: :json
    patch auto_follow_path(auto_follow), params: { auto_follow: { title: 'Remote instance', enabled: '1' } }
    assert_predicate auto_follow.reload, :enabled?
    get auto_follow_path(auto_follow)
    assert_response :success
    get edit_auto_follow_path(auto_follow)
    assert_response :success
    patch auto_follow_path(auto_follow), params: { auto_follow: { title: 'Updated' } }
    assert_equal 'Updated', auto_follow.reload.title
    patch toggle_enabled_auto_follow_path(auto_follow), params: { enabled: false }, as: :json
    assert_response :success
    assert_not auto_follow.reload.enabled?
    assert_difference('AutoFollow.count', -1) { delete auto_follow_path(auto_follow) }
  end

  test 'create saves selected accounts with the auto-follow form' do
    assert_difference('AutoFollow.count') do
      post auto_follows_path, params: {
        auto_follow: {
          title: 'Configured list', instance_name: 'Toot Wales', enabled: '1', account_ids: ['', @member.id.to_s]
        }
      }
    end

    auto_follow = AutoFollow.order(:id).last
    assert_redirected_to auto_follow_path(auto_follow)
    assert_predicate auto_follow, :enabled?
    assert_equal [@member], auto_follow.accounts.to_a
  end

  test 'edit saves accounts selected from the combined form' do
    patch auto_follow_path(@auto_follow), params: {
      auto_follow: { account_ids: ['', @member.id.to_s] }
    }

    assert_redirected_to auto_follow_path(@auto_follow)
    assert_equal [@member], @auto_follow.accounts.reload.to_a
  end

  test 'edit form removes a persisted account when its delete button submits' do
    @auto_follow.auto_follow_accounts.create!(account: @member)

    patch auto_follow_path(@auto_follow), params: {
      auto_follow: { account_ids: ['', @member.id.to_s], remove_account_id: @member.id.to_s }
    }

    assert_redirected_to edit_auto_follow_path(@auto_follow)
    assert_empty @auto_follow.accounts.reload
  end

  test 'members can be added once, reordered and removed' do
    2.times { post add_account_auto_follow_path(@auto_follow), params: { account_id: @member.id }, as: :json }
    assert_response :no_content
    assert_equal 1, @auto_follow.auto_follow_accounts.count
    post add_account_auto_follow_path(@auto_follow), params: { account_id: @creator.id }, as: :json
    ids = @auto_follow.auto_follow_accounts.pluck(:id).reverse.map(&:to_s)
    patch reorder_accounts_auto_follow_path(@auto_follow), params: { ids: ids }, as: :json
    assert_response :no_content
    assert_equal ids, @auto_follow.auto_follow_accounts.reload.pluck(:id).map(&:to_s)
    patch reorder_accounts_auto_follow_path(@auto_follow), params: { ids: [ids.first, ids.first] }, as: :json
    assert_response :unprocessable_entity
    delete remove_account_auto_follow_path(@auto_follow), params: { account_id: @member.id }, as: :json
    assert_response :no_content
    assert_equal [@creator], @auto_follow.accounts.reload.to_a
  end

  test 'cannot remove the last account from an enabled auto-follow' do
    @auto_follow.auto_follow_accounts.create!(account: @member)
    @auto_follow.update!(enabled: true)

    delete remove_account_auto_follow_path(@auto_follow), params: { account_id: @member.id }, as: :json

    assert_response :unprocessable_entity
    assert_equal 'An enabled auto-follow list must contain at least one account.', response.parsed_body.fetch('error')
    assert_equal [@member], @auto_follow.accounts.reload.to_a
  end

  test 'cannot enable an auto-follow without accounts' do
    patch toggle_enabled_auto_follow_path(@auto_follow), params: { enabled: true }, as: :json

    assert_response :unprocessable_entity
    assert_equal 'Add an account before enabling auto-follow.', response.parsed_body.fetch('error')
    assert_not @auto_follow.reload.enabled?
  end

  test 'account search works before an auto-follow list exists' do
    service = Object.new
    service.define_singleton_method(:call) { [{ id: '123', acct: 'example@remote.test' }] }
    StarterPackAccountSearchService.stub(:new, ->(*) { service }) do
      get search_accounts_auto_follows_path, params: { query: '@example@remote.test' }, as: :json
      assert_response :success
      assert_equal '123', response.parsed_body.fetch('accounts').first.fetch('id')
    end
  end

  test 'search errors return bad gateway' do
    StarterPackAccountSearchService.stub(:new, ->(*) { raise StarterPackAccountSearchService::SearchError }) do
      get search_accounts_auto_follows_path, params: { query: 'example' }, as: :json
      assert_response :bad_gateway
    end
  end

  test 'users without permission cannot search or mutate auto-follows' do
    @user.update!(role: UserRole.create!(name: 'Reader', permissions: 0))
    get search_accounts_auto_follows_path, params: { query: 'example' }, as: :json
    assert_response :forbidden
    post add_account_auto_follow_path(@auto_follow), params: { account_id: @member.id }, as: :json
    assert_response :forbidden
    delete auto_follow_path(@auto_follow), as: :json
    assert_response :forbidden
    assert AutoFollow.exists?(@auto_follow.id)
  end
end