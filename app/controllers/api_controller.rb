class ApiController < ApplicationController
  respond_to :json

  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  before_action :verify_key!

  protected

  def verify_key!
    key = request.headers['x-api-key']
    secret = request.headers['x-api-secret']

    return render json: { error: 'API Key is missing' }, status: :unauthorized unless key || secret

    return render json: { error: 'API Key is invalid' }, status: :unauthorized unless ApiKey.exists?(key: key, secret: secret)

    Rails.logger.info "API Key is valid"
  end

  def get_metadata(collection)
    {
      current_page: collection.current_page,
      next_page: collection.next_page,
      prev_page: collection.prev_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count
    }
  end
end
