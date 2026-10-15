require 'test_helper'
require 'minitest/mock'

class StarterPackAccountSearchServiceTest < ActiveSupport::TestCase
  test 'maps returned instance IDs without confusing identical usernames on other domains' do
    account = Account.create!(username: 'packsearch', display_name: 'Search', domain: 'example.org', avatar_remote_url: 'https://example.org/avatar.png')
    Account.create!(username: 'packsearch', display_name: 'Other', domain: 'other.example')
    response = Struct.new(:parsed_response) do
      def success?
        true
      end
    end.new({ 'accounts' => [{ 'id' => account.id.to_s, 'acct' => 'packsearch@example.org', 'url' => 'https://example.org/@packsearch' }] })
    token_service = Object.new
    token_service.define_singleton_method(:call) { 'test-token' }
    GenerateAdminAccessTokenService.stub(:new, ->(*) { token_service }) do
      HTTParty.stub(:get, response) do
        user = Struct.new(:id).new(123)
        result = StarterPackAccountSearchService.new('packsearch', user: user).call
        assert_equal [account.id.to_s], result.map { |row| row.fetch(:id) }
      end
    end
  end

  test 'empty search does not require a token' do
    assert_equal [], StarterPackAccountSearchService.new(' ', user: nil).call
  end

  test 'upstream failure raises a generic search error' do
    token_service = Object.new
    token_service.define_singleton_method(:call) { 'test-token' }
    response = Object.new
    response.define_singleton_method(:success?) { false }
    GenerateAdminAccessTokenService.stub(:new, ->(*) { token_service }) do
      HTTParty.stub(:get, response) do
        assert_raises(StarterPackAccountSearchService::SearchError) do
          StarterPackAccountSearchService.new('packsearch', user: Struct.new(:id).new(123)).call
        end
      end
    end
  end
end