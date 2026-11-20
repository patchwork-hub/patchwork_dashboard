require 'test_helper'

class LocalAccountSearchServiceTest < ActiveSupport::TestCase
  setup do
    @previous_local_domain = ENV['LOCAL_DOMAIN']
    @previous_web_domain = ENV['WEB_DOMAIN']
    @previous_instance_url = ENV['MASTODON_INSTANCE_URL']
    ENV['LOCAL_DOMAIN'] = 'csidnet.world'
    ENV['WEB_DOMAIN'] = nil
    ENV['MASTODON_INSTANCE_URL'] = 'https://csidnet.world'
    @account = Account.create!(username: 'nyan', display_name: 'Nyan', private_key: 'synthetic', public_key: 'synthetic')
    Account.create!(username: 'nyan', display_name: 'Remote Nyan', domain: 'other.example')
  end

  teardown do
    ENV['LOCAL_DOMAIN'] = @previous_local_domain
    ENV['WEB_DOMAIN'] = @previous_web_domain
    ENV['MASTODON_INSTANCE_URL'] = @previous_instance_url
  end

  test 'finds a local account by full handle' do
    results = LocalAccountSearchService.new('@nyan@csidnet.world').call

    assert_equal ['nyan'], results.map(&:username)
    assert_equal [@account.id], results.map(&:id)
  end

  test 'finds a local account by username@domain without a leading at' do
    results = LocalAccountSearchService.new('nyan@csidnet.world').call

    assert_equal [@account.id], results.map(&:id)
  end

  test 'finds a local account by username or display name' do
    assert_equal [@account.id], LocalAccountSearchService.new('nyan').call.map(&:id)
    assert_equal [@account.id], LocalAccountSearchService.new('Nyan').call.map(&:id)
  end

  test 'does not treat a remote handle as a local account' do
    assert_empty LocalAccountSearchService.new('@nyan@other.example').call
  end
end
