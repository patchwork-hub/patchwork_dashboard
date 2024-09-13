# frozen_string_literal: true

class CommunityRuleService < BaseService
  def call(options = {})
    @options = options
    @community_id = options[:community_id].to_i
    @description = options[:description]
    create_rule!
    create_community_rule!
  rescue StandardError => e
    handle_error(e)
  end

  private

  def create_rule!
    @rule = Rule.find_or_create_by!(description: @options[:description])
  end

  def create_community_rule!
    CommunityRule.find_or_create_by!(
      patchwork_rules_id: @rule.id,
      patchwork_community_id: @community_id
    )
  end

  def handle_error(exception)
    Rails.logger.error("Failed to create community rule: #{exception.message}")
    raise
  end
end
