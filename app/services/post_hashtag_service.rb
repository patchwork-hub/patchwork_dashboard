class PostHashtagService < BaseService
  def call(options = {})
    @community_id = options[:community_id]
    @hashtags = extract_hashtags(options)
    create!
  end

  private

  def extract_hashtags(options)
    (1..3).map do |i|
      hashtag = options[:"hashtag#{i}"]&.gsub('#', '')&.downcase
      { hashtag: hashtag, patchwork_community_id: @community_id } if hashtag.present?
    end.compact
  end

  def create!
    @hashtags.each do |hashtag_attributes|
      PostHashtag.find_or_create_by(hashtag_attributes)
    end
  end
end
