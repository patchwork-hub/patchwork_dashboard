# frozen_string_literal: true

class Form::CommunityRule
  include ActiveModel::Model

  attr_accessor :id, :community_id, :rule_id, :description

  def initialize(options = {})
    options = options.is_a?(Hash) ? options.symbolize_keys : options
    @id = options.fetch(:id) if options[:id]
    @rule_id = options.fetch(:rule_id) if options[:rule_id]
    @community_id = options.fetch(:community_id) if options[:community_id]
    @description = options.fetch(:description, nil) if options[:description]
  end
end
