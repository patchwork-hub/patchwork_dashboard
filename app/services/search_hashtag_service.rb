require 'httparty'

class SearchHashtagService
  def initialize(api_base_url, token, query)
    @api_base_url = api_base_url
    @token = token
    @query = query
  end

  def call
    response = HTTParty.get("#{@api_base_url}/api/v2/search",
      query: { q: @query, type: 'hashtags', limit: 1 },
      headers: { 'Authorization' => "Bearer #{@token}" }
    )

    return nil unless response.success?

    hashtag = response['hashtags']&.first

    if hashtag.nil? || hashtag['name'].to_s.casecmp(@query.to_s) != 0
      hashtag = Tag.find_or_create_case_insensitive!(name: @query, display_name: @query)
    end

    hashtag ? { name: hashtag['name'] } : nil
  end
end
