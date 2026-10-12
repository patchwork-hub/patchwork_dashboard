class BlueskyBridgePropagationJob < ApplicationJob
  queue_as :default

  def perform(target_type, target_id, did_value)
    BlueskyBridgePropagationService.new.call(target_type, target_id, did_value)
  end
end