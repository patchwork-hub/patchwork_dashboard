class KeywordFilterGroupApiService
  require 'httparty'

  def initialize(name)
    @name = name
    @host = ENV['PATCHWORK_HUB_URL']

    raise CustomError.new("`PATCHWORK_HUB_URL` is not set!") unless @host

    @path = "/api/v1/keyword_filter_groups"
    @api_key = ApiKey.first
  end

  def get_keywords
    begin
      conn = Faraday.new(
        url: @host,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': @api_key.key,
          'x-api-secret': @api_key.secret
        }
      )

      response = conn.get(@path) do |req|
        req.body = {name: @name}.to_json
      end

      JSON.parse(response.body)
    rescue => e
      Rails.logger.error("Failed to get keywords: #{e}")
      []
    end
  end
end
