class Form::PostHashtag
  include ActiveModel::Model

  attr_accessor :id, :hashtag

  def initialize(options = {})
    options = options.is_a?(Hash) ? options.symbolize_keys : options
    @hashtag1 = options.fetch(:hashtag1) if options[:hashtag1]
    @hashtag2 = options.fetch(:hashtag2) if options[:hashtag2]
    @hashtag3 = options.fetch(:hashtag3) if options[:hashtag3]
  end
end
