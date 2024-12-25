class ApiController < ApplicationController
  respond_to :json

  skip_before_action :handle_authentication
  skip_before_action :verify_authenticity_token

  before_action :verify_key!

  protected

  def verify_key!
    key = request.headers['x-api-key']
    secret = request.headers['x-api-secret']

    return render json: { error: 'API Key is missing' }, status: :unauthorized unless key || secret

    @api_key = ApiKey.find_by(key: key, secret: secret)

    return render json: { error: 'API Key is invalid' }, status: :unauthorized unless @api_key.present?

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

  def authenticate_user_from_header
    token = bearer_token
    return render json: { error: 'The access token is invalid' }, status: :unauthorized unless token

    user_info = validate_token(token)

    if user_info
      user = User.find_by(id: user_info["resource_owner_id"])
      if user
        sign_in(user)
      else
        render json: { error: 'User not found' }, status: :unauthorized
      end
    else
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end

  private

  def bearer_token
    pattern = /^Bearer /
    header  = request.headers['Authorization']
    header.gsub(pattern, '') if header && header.match(pattern)
  end

end
