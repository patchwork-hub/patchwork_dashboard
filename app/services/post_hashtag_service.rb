class PostHashtagService < BaseService
  def call(options = {})
    @community_id = options[:community_id]
    @hashtag = options[:hashtag]&.gsub('#', '')
    create!
  end

  private

  def create!
    return unless @hashtag.present?

    PostHashtag.find_or_create_by!(
      hashtag: @hashtag,
      patchwork_community_id: @community_id
    )
  end
end
