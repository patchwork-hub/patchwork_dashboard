class CustomEmojisController < ApplicationController
  before_action :authorize_custom_emojis!
  before_action :set_custom_emoji, only: [:edit, :update, :destroy]
  
  def index
    @records = filtered_custom_emojis.eager_load(:local_counterpart, :category).page(params[:page])
    @form          = Form::CustomEmojiBatch.new
  end

  def new
    @custom_emoji = CustomEmoji.new
  end

  def create
    @custom_emoji = CustomEmoji.new(resource_params)
    
    # Handle category creation for local emojis
    if @custom_emoji.local? && params[:custom_emoji][:category_name].present? && params[:custom_emoji][:category_id].blank?
      category = CustomEmojiCategory.find_or_create_by(name: params[:custom_emoji][:category_name])
      @custom_emoji.category_id = category.id
    end

    if @custom_emoji.save
      # log_action :create, @custom_emoji
      redirect_to custom_emojis_path, notice: 'Custom emoji was successfully created.'
    else
      render :new
    end
  end

  def destroy
    @custom_emoji.destroy
    redirect_to custom_emojis_path, notice: 'Custom emoji was successfully deleted.'
  end

  def edit
    # authorize :custom_emoji, :update?
  end

  def update
    # Handle category creation for local emojis
    if @custom_emoji.local? && params[:custom_emoji][:category_name].present? && params[:custom_emoji][:category_id].blank?
      category = CustomEmojiCategory.find_or_create_by(name: params[:custom_emoji][:category_name])
      params[:custom_emoji] = params[:custom_emoji].merge(category_id: category.id)
    end

    if @custom_emoji.update(resource_params)
      redirect_to custom_emojis_path, notice: 'Custom emoji was successfully updated.'
    else
      render :edit
    end
  end

  def batch

    @form = Form::CustomEmojiBatch.new(form_custom_emoji_batch_params.merge(current_account: current_account, action: action_from_button))
    @form.save
  rescue ActionController::ParameterMissing
    flash[:alert] = I18n.t('admin.custom_emojis.no_emoji_selected')
  rescue Mastodon::NotPermittedError
    flash[:alert] = I18n.t('admin.custom_emojis.not_permitted')
  ensure
    redirect_to admin_custom_emojis_path(filter_params)
  end

  private

  def resource_params
    params
      .require(:custom_emoji)
      .permit(:shortcode, :image, :visible_in_picker, :disabled, :category_id, :category_name)
  end

  def filtered_custom_emojis
    CustomEmojiFilter.new(filter_params).results
  end

  def filter_params
    params.slice(:page, :filter, :search, *CustomEmojiFilter::KEYS).permit(:page, :filter, :search, *CustomEmojiFilter::KEYS)
  end

  def action_from_button
    if params[:update]
      'update'
    elsif params[:list]
      'list'
    elsif params[:unlist]
      'unlist'
    elsif params[:enable]
      'enable'
    elsif params[:disable]
      'disable'
    elsif params[:copy]
      'copy'
    elsif params[:delete]
      'delete'
    end
  end

  def form_custom_emoji_batch_params
    params
      .require(:form_custom_emoji_batch)
      .permit(:action, :category_id, :category_name, custom_emoji_ids: [])
  end

  def set_custom_emoji
    @custom_emoji = CustomEmoji.find(params[:id])
  end

  def authorize_custom_emojis!
    authorize :custom_emoji, "#{action_name}?"
  end
end