require 'test_helper'

class RemoteAccountVerifyServiceTest < ActiveSupport::TestCase
  setup do
    @previous_local_domain = ENV['LOCAL_DOMAIN']
    ENV['LOCAL_DOMAIN'] = 'findout.media'
  end

  teardown do
    ENV['LOCAL_DOMAIN'] = @previous_local_domain
  end

  test 'finds a local account with a nil domain' do
    account = Account.create!(
      username: 'nyan',
      display_name: 'Nyan',
      private_key: 'synthetic',
      public_key: 'synthetic'
    )
    service = RemoteAccountVerifyService.new('token', 'findout.media')
    service.instance_variable_set(:@remote_account, { 'username' => 'nyan' })

    assert_equal account.id, service.fetch_remote_account_id
  end
end
