require 'test_helper'
require 'tmpdir'
require 'stringio'
require 'minitest/mock'

class StarterPackImportServiceTest < ActiveSupport::TestCase
  test 'profile URL is tried when a remote handle returns no results' do
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('fallback')
      directory.mkpath
      identity = { acct: 'fallback@remote.example', url: 'https://remote.example/@fallback', uri: 'https://remote.example/users/fallback' }
      directory.join('starter_pack_list.json').write([{ id: '1', title: 'Fallback pack', collected_by: identity }].to_json)
      directory.join('starter_pack_1.json').write([identity].to_json)
      queries = []
      resolver = ->(query, **_options) do
        queries << query
        service = Object.new
        service.define_singleton_method(:call) do
          next [] unless query == identity[:url]

          account = Account.create!(username: 'fallback', domain: 'remote.example', display_name: 'Fallback', uri: identity[:uri], url: identity[:url])
          [{ id: account.id.to_s, acct: identity[:acct], profile_url: identity[:url] }]
        end
        service
      end
      StarterPackAccountSearchService.stub(:new, resolver) do
        StarterPackImportService.new(data_dir: root, user: User.new, output: StringIO.new).call
      end
      assert_equal [identity[:acct], identity[:url]], queries
      pack = StarterPack.find_by!(instance_name: 'fallback', title: 'Fallback pack')
      assert_equal [pack.created_by], pack.accounts.to_a
    end
  end

  test 'best effort import skips an unresolved creator and member but adds available members' do
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('besteffort')
      directory.mkpath
      directory.join('starter_pack_list.json').write([{ id: '1', title: 'Best effort', collected_by: { acct: 'unavailablecreator@remote.example' } }].to_json)
      directory.join('starter_pack_1.json').write([{ acct: 'available@remote.example' }, { acct: 'unavailable@remote.example' }].to_json)
      resolver = ->(query, **_options) do
        service = Object.new
        service.define_singleton_method(:call) do
          next [] unless query == 'available@remote.example'

          account = Account.create!(username: 'available', domain: 'remote.example', display_name: 'Available')
          [{ id: account.id.to_s, acct: query }]
        end
        service
      end
      output = StringIO.new
      StarterPackAccountSearchService.stub(:new, resolver) do
        StarterPackImportService.new(data_dir: root, user: User.new, skip_unresolved: true, output: output).call
      end
      pack = StarterPack.find_by!(instance_name: 'besteffort', title: 'Best effort')
      assert_nil pack.created_by
      assert_equal ['available'], pack.accounts.pluck(:username)
      assert_includes output.string, 'Skipping unresolved pack 1 creator'
      assert_includes output.string, 'Skipping unresolved pack 1 member 2'
      assert_includes output.string, '1/2 accounts matched'
    end
  end

  test 'best effort import still aborts on search connection or authentication failure' do
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('failedconnection')
      directory.mkpath
      directory.join('starter_pack_list.json').write([{ id: '1', title: 'Connection failure' }].to_json)
      directory.join('starter_pack_1.json').write([{ acct: 'unavailable@remote.example' }].to_json)
      service = Object.new
      service.define_singleton_method(:call) { raise StarterPackAccountSearchService::SearchError }
      StarterPackAccountSearchService.stub(:new, ->(*) { service }) do
        assert_no_difference('StarterPack.count') do
          assert_raises(StarterPackImportService::ImportError) do
            StarterPackImportService.new(data_dir: root, user: User.new, skip_unresolved: true, output: StringIO.new).call
          end
        end
      end
    end
  end

  test 'list IDs select their account files and remote accounts are searched and added' do
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('remoteimport')
      directory.mkpath
      identity = ->(name) { { id: '99', acct: "#{name}@remote.example", uri: "https://remote.example/users/#{name}" } }
      creator = identity.call('remotecreator')
      first = identity.call('firstmember')
      second = identity.call('secondmember')
      directory.join('starter_pack_list.json').write([
        { id: '2', title: 'Pack two', collected_by: creator },
        { id: '1', title: 'Pack one', collected_by: creator }
      ].to_json)
      directory.join('starter_pack_2.json').write([second].to_json)
      directory.join('starter_pack_1.json').write([first, first, creator].to_json)
      directory.join('starter_pack_3.json').write([identity.call('unlisted')].to_json)
      queries = []
      user = User.new
      resolver = ->(query, **options) do
        queries << query
        assert_equal user, options[:user]
        service = Object.new
        service.define_singleton_method(:call) do
          username, domain = query.split('@', 2)
          account = Account.create!(username: username, domain: domain, display_name: 'Imported remote', uri: "https://#{domain}/users/#{username}")
          [{ id: account.id.to_s, acct: query }]
        end
        service
      end
      output = StringIO.new
      StarterPackAccountSearchService.stub(:new, resolver) do
        importer = -> { StarterPackImportService.new(data_dir: root, user: user, output: output).call }
        assert_difference('StarterPack.count', 2) { importer.call }
        assert_equal %w[remotecreator@remote.example secondmember@remote.example firstmember@remote.example], queries
        packs = StarterPack.for_instance('remoteimport').ordered.to_a
        assert_equal ['Pack two', 'Pack one'], packs.map(&:title)
        assert_equal ['secondmember'], packs[0].accounts.pluck(:username)
        assert_equal %w[firstmember remotecreator], packs[1].accounts.pluck(:username)
        assert_equal packs[0].created_by, packs[1].created_by
        assert packs.flat_map(&:accounts).all? { |account| account.domain == 'remote.example' }
        assert_not Account.exists?(username: 'unlisted', domain: 'remote.example')
        assert_no_difference(['StarterPack.count', 'StarterPackAccount.count']) { importer.call }
        assert_equal 3, queries.size
      end
    end
  end

  test 'unqualified remote snapshot handles use the profile URL and never match a local namesake' do
    local_account = Account.create!(username: 'namesake', display_name: 'Local namesake', private_key: 'synthetic', public_key: 'synthetic')
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('remoteprofile')
      directory.mkpath
      profile_url = 'https://remote.example/@namesake'
      directory.join('starter_pack_list.json').write([{ id: '1', title: 'Remote profile' }].to_json)
      directory.join('starter_pack_1.json').write([{ id: local_account.id.to_s, acct: 'namesake', url: profile_url }].to_json)
      resolver = ->(query, **_options) do
        assert_equal profile_url, query
        service = Object.new
        service.define_singleton_method(:call) do
          account = Account.create!(username: 'namesake', domain: 'remote.example', display_name: 'Remote namesake', url: profile_url)
          [{ id: account.id.to_s, acct: 'namesake@remote.example', profile_url: profile_url }]
        end
        service
      end
      StarterPackAccountSearchService.stub(:new, resolver) do
        StarterPackImportService.new(data_dir: root, user: User.new, output: StringIO.new).call
      end
      pack = StarterPack.find_by!(instance_name: 'remoteprofile', title: 'Remote profile')
      assert_equal ['remote.example'], pack.accounts.pluck(:domain)
      assert_not_includes pack.accounts, local_account
    end
  end

  test 'missing accounts can be resolved before adding memberships' do
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('resolved')
      directory.mkpath
      identity = { acct: 'resolvedimport@example.org', uri: 'https://example.org/users/resolvedimport' }
      directory.join('starter_pack_list.json').write([{ id: '1', title: 'Resolved pack', collected_by: identity }].to_json)
      directory.join('starter_pack_1.json').write([identity].to_json)
      service = Object.new
      service.define_singleton_method(:call) do
        Account.create!(username: 'resolvedimport', display_name: 'Resolved', domain: 'example.org', uri: identity[:uri])
        []
      end
      user = User.new
      resolver = ->(query, **options) do
        assert_equal identity[:acct], query
        assert_equal user, options[:user]
        service
      end
      StarterPackAccountSearchService.stub(:new, resolver) do
        StarterPackImportService.new(data_dir: root, resolve_missing: true, user: user, output: StringIO.new).call
      end
      pack = StarterPack.find_by!(instance_name: 'resolved', title: 'Resolved pack')
      assert_equal [pack.created_by], pack.accounts.to_a
      assert_equal 'resolvedimport', pack.created_by.username
      assert_equal 1, pack.position
    end
  end

  test 'dry run never resolves accounts remotely' do
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('preview')
      directory.mkpath
      directory.join('starter_pack_list.json').write([{ id: '1', title: 'Preview' }].to_json)
      directory.join('starter_pack_1.json').write([{ acct: 'missing@example.org' }].to_json)
      resolver = ->(*) { flunk 'Dry runs must not resolve remote accounts' }
      output = StringIO.new
      StarterPackAccountSearchService.stub(:new, resolver) do
        assert_no_difference('StarterPack.count') do
          StarterPackImportService.new(data_dir: root, resolve_missing: true, dry_run: true, output: output).call
        end
      end
      assert_includes output.string, 'Missing accounts were not resolved during the dry run.'
      assert_raises(ArgumentError) do
        StarterPackImportService.new(data_dir: root, resolve_missing: true, output: output).call
      end
    end
  end

  test 'failed resolution preserves existing pack memberships' do
    account = Account.create!(username: 'preservedimport', display_name: 'Preserved', domain: 'example.org')
    pack = StarterPack.create!(title: 'Preserved', instance_name: 'preserved', position: 7)
    pack.starter_pack_accounts.create!(account: account)
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('preserved')
      directory.mkpath
      directory.join('starter_pack_list.json').write([{ id: '1', title: 'Preserved' }].to_json)
      directory.join('starter_pack_1.json').write([{ acct: 'missing@example.org' }].to_json)
      service = Object.new
      service.define_singleton_method(:call) { [] }
      StarterPackAccountSearchService.stub(:new, ->(*) { service }) do
        assert_raises(StarterPackImportService::ImportError) do
          StarterPackImportService.new(data_dir: root, resolve_missing: true, user: User.new, output: StringIO.new).call
        end
      end
      assert_equal [account], pack.accounts.reload.to_a
      assert_equal 7, pack.reload.position
      output = StringIO.new
      StarterPackAccountSearchService.stub(:new, ->(*) { service }) do
        StarterPackImportService.new(data_dir: root, resolve_missing: true, skip_unresolved: true, user: User.new, output: output).call
      end
      assert_equal [account], pack.accounts.reload.to_a
      assert_equal 7, pack.reload.position
      assert_includes output.string, 'existing pack unchanged'
    end
  end

  test 'import matches URI and handles, is repeatable, and dry run leaves no rows' do
    account = Account.create!(username: 'packimport', display_name: 'Import', domain: 'example.org', uri: 'https://example.org/users/packimport')
    Dir.mktmpdir do |root|
      directory = Pathname.new(root).join('findout')
      directory.mkpath
      directory.join('starter_pack_list.json').write([{ id: '2', title: 'Imported', description: 'Example', collected_by: { id: '1', uri: account.uri } }].to_json)
      directory.join('starter_pack_2.json').write([{ id: '2', acct: 'packimport@example.org' }, { acct: 'missing@example.org' }].to_json)
      output = StringIO.new
      assert_no_difference('StarterPack.count') do
        StarterPackImportService.new(data_dir: root, resolve_missing: false, dry_run: true, output: output).call
      end
      assert_difference('StarterPack.count', 1) do
        StarterPackImportService.new(data_dir: root, resolve_missing: false, output: output).call
      end
      assert_no_difference('StarterPack.count') do
        StarterPackImportService.new(data_dir: root, resolve_missing: false, output: output).call
      end
      pack = StarterPack.find_by!(instance_name: 'findout', title: 'Imported')
      assert_equal account, pack.created_by
      assert_equal [account], pack.accounts.to_a
      assert_includes output.string, '1/2 accounts matched'
    end
  end
end