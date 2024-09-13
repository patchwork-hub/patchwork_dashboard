# frozen_string_literal: true

class CommunityHashtagPostService < BaseService
  class InvalidHashtagError < StandardError; end

  def call(account, options = {})
    @account = account
    @options = options
    prepare_params!
    community_create_hashtag!
  end

  def community_hashtag_attribute
    {
      hashtag: @hashtag,
      name: @name,
      patchwork_community_id: @community_id
    }.compact
  end

  def community_create_hashtag!
    CommunityHashtag.find_or_create_by(community_hashtag_attribute)
  end

  def prepare_params!
    validate_hashtag!(@options[:hashtag])

    @hashtag = @options[:hashtag].gsub('#', '').downcase
    @name = @options[:hashtag].gsub('#', '')
    @community_id = @options[:community_id]
  end

  def validate_hashtag!(hashtag)
    if hashtag.include?(' ')
      raise InvalidHashtagError, 'Hashtag cannot contain spaces.'
    end
  end
end
