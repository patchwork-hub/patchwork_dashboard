require 'test_helper'

class AutoFollowTest < ActiveSupport::TestCase
  test 'normalizes instance names and requires a title and instance' do
    auto_follow = AutoFollow.create!(title: 'Example', instance_name: 'Toot Wales')
    assert_equal 'tootwales', auto_follow.instance_name
    assert_not AutoFollow.new(title: '', instance_name: '---').valid?
  end

  test 'instance name is unique after normalization' do
    AutoFollow.create!(title: 'First', instance_name: 'Toot Wales')
    duplicate = AutoFollow.new(title: 'Second', instance_name: 'tootwales')
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:instance_name], 'has already been taken'
  end

  test 'enabled auto-follow requires at least one account' do
    auto_follow = AutoFollow.new(title: 'Example', instance_name: 'twt', enabled: true)
    assert_not auto_follow.valid?
    assert_includes auto_follow.errors[:enabled], 'Add an account before enabling auto-follow.'

    auto_follow.enabled = false
    assert auto_follow.valid?
  end

  test 'accounts are unique, ordered and deleted with the auto-follow' do
    auto_follow = AutoFollow.create!(title: 'Example', instance_name: 'twt')
    first = Account.create!(username: 'autofirst', display_name: 'First', domain: 'example.org')
    second = Account.create!(username: 'autosecond', display_name: 'Second', domain: 'example.org')
    auto_follow.auto_follow_accounts.create!(account: first, position: 2)
    auto_follow.auto_follow_accounts.create!(account: second, position: 1)
    assert_equal [second, first], auto_follow.accounts.to_a
    assert_not auto_follow.auto_follow_accounts.build(account: first).valid?
    auto_follow.destroy!
    assert_empty AutoFollowAccount.where(patchwork_auto_follow_id: auto_follow.id)
  end

  test 'database cascades account membership when an account is deleted' do
    auto_follow = AutoFollow.create!(title: 'Example', instance_name: 'twt')
    account = Account.create!(username: 'autodeleted', display_name: 'Deleted', domain: 'example.org')
    auto_follow.auto_follow_accounts.create!(account: account)
    account.delete
    assert_empty auto_follow.auto_follow_accounts.reload
  end
end