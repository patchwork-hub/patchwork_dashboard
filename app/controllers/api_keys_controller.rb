class ApiKeysController < ApplicationController
  respond_to :html, :json
  load_and_authorize_resource

  def index
    @api_key = ApiKey.first
  end

  def create
    if @api_key.save
      redirect_to api_keys_path, notice: 'API key created.'
    else
      flash[:error] = @api_key.errors.full_messages
      render :new
    end
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

  def api_key_params
    params.require(:api_key).permit(:key, :secret)
  end
end
