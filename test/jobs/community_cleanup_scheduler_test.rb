require "test_helper"

class CommunityCleanupSchedulerTest < ActiveSupport::TestCase
  class CleanupRelation
    def initialize(community)
      @community = community
    end

    def not(*)
      self
    end

    def where(*)
      self
    end

    def empty?
      false
    end

    def count
      1
    end

    def find_each
      yield @community
    end
  end

  test "keeps remote and account work outside the destroy transaction" do
    transaction_open = false
    remote_transaction_state = nil
    destroy_transaction_state = nil
    community_admins = Struct.new(:account_ids) do
      def pluck(*)
        account_ids
      end
    end.new([])
    community = Struct.new(:id, :community_admins).new(7, community_admins)
    community.define_singleton_method(:destroy!) do
      destroy_transaction_state = transaction_open
    end
    cleanup_service = Object.new
    cleanup_service.define_singleton_method(:call) do |_community|
      remote_transaction_state = transaction_open
      true
    end
    transaction = proc do |&block|
      transaction_open = true
      block.call
    ensure
      transaction_open = false
    end

    Community.stub(:where, CleanupRelation.new(community)) do
      DeleteCommunityInstanceService.stub(:new, cleanup_service) do
        ActiveRecord::Base.stub(:transaction, transaction) do
          Account.stub(:where, []) do
            Scheduler::CommunityCleanupScheduler.new.perform
          end
        end
      end
    end

    assert_equal false, remote_transaction_state
    assert_equal true, destroy_transaction_state
  end
end