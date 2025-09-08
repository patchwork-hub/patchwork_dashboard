class ApiController < ApplicationController
  respond_to :json

  # Include internationalization support for API controllers
  include LocaleDetection
  # Include standardized API response helpers with I18n support
  include ApiResponseHelper

  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  before_action :verify_key!

  helper_method :current_remote_account

  helper_method :local_account?

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

  def check_authorization_header
    if request.headers['Authorization'].present? && params[:instance_domain].present?
      validate_mastodon_account
    else
      authenticate_user_from_header
    end
  end

  def authenticate_user_from_header
    token = bearer_token
    return render_unauthorized unless token

    user_info = validate_token(token)
    
    if user_info
      user = User.find_by(id: user_info["resource_owner_id"])
      if user
        sign_in(user)
      else
        render_unauthorized
      end
    else
      render_forbidden
    end
  end

  def validate_mastodon_account
    token = bearer_token
    return render_unauthorized unless token && !instance_domain.nil?

    acc_id = RemoteAccountVerifyService.new(token, instance_domain).call.fetch_remote_account_id

    if acc_id
      @current_remote_account = Account.find_by(id: acc_id)
    else
      render_unauthorized
    end
  end

  def authenticate_client_credentials
    client_id = request.headers['client-id']
    client_secret = request.headers['client-secret']

    # Custom authentication logic for client credentials for old mobile apps
    return true unless client_id || client_secret

    client = Doorkeeper::Application.find_by(uid: client_id, secret: client_secret)
    
    return true if client

    render_unauthorized
  end

  private

  def bearer_token
    pattern = /^Bearer /
    header  = request.headers['Authorization']
    header.gsub(pattern, '') if header && header.match(pattern)
  end

  def instance_domain
    params[:instance_domain].present? ? params[:instance_domain] : nil
  end

  def validate_token(token)
    begin
      env = ENV.fetch('RAILS_ENV', nil)
      url = case env
        when 'staging'
          'https://staging.patchwork.online/oauth/token/info'
        when 'production'
          'https://channel.org/oauth/token/info'
        else
          'http://localhost:3001/oauth/token/info'
        end
      response = HTTParty.get(url, headers: { 'Authorization' => "Bearer #{token}" })
      JSON.parse(response.body)
    rescue HTTParty::Error => e
      Rails.logger.error "Error fetching user info: #{e.message}"
      nil
    end
  end

  def current_remote_account
    return @current_remote_account if defined?(@current_remote_account)
  end

  def local_account?
    if request.headers['Authorization'].present? && params[:instance_domain].present?
      return false if defined?(@current_remote_account)
    end

    true
  end
end
