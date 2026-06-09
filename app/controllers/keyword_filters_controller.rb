class KeywordFiltersController < ApplicationController
  before_action :authorize_keyword_filter!
  before_action :set_keyword_filter_group
  before_action :set_keyword_filter, only: [:edit, :update, :destroy]

  def index
  end

  def new
    @keyword_filter = KeywordFilter.new
    @keyword_filter_groups = KeywordFilterGroup.all
  end

  def create
    @keyword_filter = @keyword_filter_group.keyword_filters.build(keyword_filter_params)
    if @keyword_filter.save
      add_update_redis_filter
      redirect_to @keyword_filter_group, notice: 'A filter keyword was successfully created!'
    else
      flash[:error] = @keyword_filter.errors.full_messages
      render :new
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      KeywordFilterGroup.transaction do
        destroy_redis_filter
        if @keyword_filter_group.update(keyword_filter_group_params) && @keyword_filter.update(keyword_filter_params)
          add_update_redis_filter
          format.html { redirect_to @keyword_filter_group, notice: 'Keyword filter and group were successfully updated.' }
          format.json { render json: @keyword_filter, status: :ok }
        else
          format.html { render :edit }
          format.json { render json: { errors: @keyword_filter.errors.full_messages + @keyword_filter_group.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end
  end

  def destroy
    destroy_redis_filter
    @keyword_filter.destroy
    respond_to do |format|
      format.html { redirect_to @keyword_filter_group, notice: 'Keyword filter and group were successfully deleted.' }
      format.json { head :no_content }
    end
  end

  private

  def set_keyword_filter_group
    @keyword_filter_group = KeywordFilterGroup.find(params[:keyword_filter_group_id])
  end

  def set_keyword_filter
    @keyword_filter = @keyword_filter_group.keyword_filters.find(params[:id])
  end

  def keyword_filter_params
    params.require(:keyword_filter).permit(:keyword, :filter_type, :keyword_filter_group_id)
  end

  def keyword_filter_group_params
    params.require(:keyword_filter_group).permit(:name)
  end

  def authorize_keyword_filter!
    authorize :keyword_filter, "#{action_name}?"
  end

  def add_update_redis_filter
    redis_key = KeywordFilterGroup.get_redis_key_name(@keyword_filter_group&.server_setting&.name)
    KeywordFilterGroup.update_create_redis_filter(redis_key, keyword_filter_params[:keyword], @keyword_filter_group&.server_setting.id, keyword_filter_params[:filter_type], is_active = true, @keyword_filter_group.id, is_custom = true)
  end

  def destroy_redis_filter
    KeywordFilterGroup.redised_keyword_exists?(@keyword_filter.keyword, @keyword_filter.filter_type, @keyword_filter_group&.server_setting&.name, true)
  end
end
