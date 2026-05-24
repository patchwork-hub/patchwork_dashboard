class ApiKeysController < ApplicationController
  before_action :authorize_api_keys!
  before_action :set_api_key, only: [:edit, :update]

  respond_to :html, :json

  def index
    @api_key = ApiKey.first
  end

  def new
    @api_key = ApiKey.new
  end

  def create
    @api_key = ApiKey.new(api_key_params)
    if @api_key.save
      redirect_to api_keys_path, notice: 'API key created.'
    else
      flash[:error] = @api_key.errors.full_messages
      render :new
    end
  end

  def edit
  end

  def update
    if @api_key.update(api_key_params)
      redirect_to api_keys_path, notice: 'API key updated.'
    else
      flash[:error] = @api_key.errors.full_messages
      render :edit
    end
  end

  private

  def set_api_key
    @api_key = ApiKey.find(params[:id])
  end

  def api_key_params
    params.require(:api_key).permit(:key, :secret)
  end

  def authorize_api_keys!
    authorize :api_keys, "#{action_name}?"
  end
end
