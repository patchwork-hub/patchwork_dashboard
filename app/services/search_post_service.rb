require 'httparty'

class SearchPostService
  def initialize(api_base_url, token, query)
    @api_base_url = api_base_url
    @token = token
    @query = query
  end

  def call
    response = HTTParty.get("#{@api_base_url}/api/v2/search",
      query: { q: @query, type: 'statuses', resolve: true, limit: 1 },
      headers: { 'Authorization' => "Bearer #{@token}" }
    )
    if response.success?
      return response['statuses']&.first&.dig('id')
    end

    nil
  end
end
