class Form::CommunityHashtag
  include ActiveModel::Model

  attr_accessor :id, :community_id, :hashtag_id, :hashtag

  def initialize(options = {})
    options = options.is_a?(Hash) ? options.symbolize_keys : options
    @hashtag = options.fetch(:hashtag) if options[:hashtag]
    @id = options.fetch(:id) if options[:id]
    @community_id = options.fetch(:community_id) if options[:community_id]
    @hashtag_id = options.fetch(:hashtag_id, nil) if options[:hashtag_id]
  end
end
