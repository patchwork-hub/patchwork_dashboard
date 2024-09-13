class UpdateHashtagService < BaseService
  def call(options = {})
    @community_id = options[:community_id]
    @id = options[:id]
    @hashtag = format_hashtag(options[:hashtag])
    update!
  end

  private

  def format_hashtag(hashtag)
    hashtag&.gsub('#', '')&.downcase
  end

  def update!
    PostHashtag.find(@id).update!(hashtag: @hashtag, patchwork_community_id: @community_id)
  end
end
