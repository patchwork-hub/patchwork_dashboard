class KeywordFilterGroupsController < ApplicationController
  before_action :authorize_keyword_filter_group!
  before_action :set_keyword_filter_group, only: [:show, :edit, :update, :destroy, :update_is_active, :download_csv]

  def index
    @keyword_filter_groups = KeywordFilterGroup.all
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: prepare_filter_group_data }
    end
  end

  def new
    @keyword_filter_group = KeywordFilterGroup.new
    @keyword_filter_group.keyword_filters.build
  end

  def create
    @keyword_filter_group = KeywordFilterGroup.find_or_initialize_by(name: params[:keyword_filter_group][:name], server_setting_id: params[:keyword_filter_group][:server_setting_id])
    @keyword_filter_group.assign_attributes(keyword_filter_group_params)

    if @keyword_filter_group.save
      save_to_redis
      render json: { success: true }
    else
      render json: { success: false, error: @keyword_filter_group.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @keyword_filter_group.update(keyword_filter_group_params)
      redirect_to @keyword_filter_group, notice: 'Keyword filter group and keyword filter were successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    delete_redis_hashtags_by_group_id
    @keyword_filter_group.destroy
    respond_to do |format|
      format.html { redirect_back fallback_location: keyword_filter_groups_url, notice: 'Keyword Filter Group deleted successfully' }
      format.json { render json: { success: true, message: 'Keyword Filter Group deleted successfully' } }
    end
  end

  def update_is_active
    if @keyword_filter_group.update(is_active: params[:keyword_filter_group][:is_active])
      update_redis_filters
      render json: { success: true }
    else
      render json: { success: false, error: @keyword_filter_group.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def download_csv
    require 'csv'
    filters = @keyword_filter_group.keyword_filters
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["Name", "Server Setting", "Is Active", "Keyword", "Filter Type"]
      filters.each do |kf|
        csv << [
          @keyword_filter_group.name,
          @keyword_filter_group.server_setting&.name,
          @keyword_filter_group.is_active ? 'True' : 'False',
          kf.keyword,
          kf.filter_type
        ]
      end
    end
    send_data csv_data, filename: "#{@keyword_filter_group.server_setting&.name&.parameterize}-#{@keyword_filter_group.name&.parameterize}.csv"
  end

  def download_csv_by_server_setting
    require 'csv'
    server_setting_id = params[:server_setting_id]
    server_setting = ServerSetting.find_by_id(server_setting_id)
    keyword_filters = KeywordFilter.joins(:keyword_filter_group)
                                   .where(keyword_filter_groups: { server_setting_id: server_setting_id })

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["Group Name", "Server Setting", "Group Active", "Keyword", "Filter Type", "Custom Group"]
      keyword_filters.find_each do |kf|
        group = kf.keyword_filter_group
        csv << [
          group&.name,
          group&.server_setting&.name,
          group&.is_active ? 'True' : 'False',
          kf.keyword,
          kf.filter_type,
          group&.is_custom ? 'True' : 'False'
        ]
      end
    end

    send_data csv_data, filename: "#{server_setting&.name&.parameterize}.csv"
  end

  private

  def set_keyword_filter_group
    @keyword_filter_group = KeywordFilterGroup.find(params[:id])
  end

  def keyword_filter_group_params
    params.require(:keyword_filter_group).permit(:name, :server_setting_id, keyword_filters_attributes: [:id, :keyword, :filter_type, :_destroy])
  end

  def prepare_filter_group_data
    data = {
      name: @keyword_filter_group.name,
      server_setting: ServerSetting.find_by_id(@keyword_filter_group.server_setting_id)&.name,
      is_active: @keyword_filter_group.is_active ? '<i class="fa-solid fa-check" style="color: green;"></i>' : '<i class="fa-solid fa-xmark" style="color: red;"></i>',
      keyword_filters: @keyword_filter_group.keyword_filters.map do |kf|
        {
          id: kf.id,
          keyword: kf.keyword,
          is_custom_group: @keyword_filter_group.is_custom,
          edit_url: keyword_filter_group_keyword_filter_path(@keyword_filter_group, kf) + '/edit',
          delete_url: keyword_filter_group_keyword_filter_path(@keyword_filter_group, kf)
        }
      end
    }

    { draw: params[:draw].to_i, recordsTotal: 1, recordsFiltered: 1, data: [data] }
  end

  def update_redis_filters
    redis = RedisService.client(namespace: 'channel')
    redis_key = KeywordFilterGroup.get_redis_key_name(@keyword_filter_group&.server_setting&.name)
    parsed_entries = redis.hgetall(redis_key).values.map { |entry| JSON.parse(entry) }
    filtered_entries = parsed_entries.select { |entry| entry['group_id'] == @keyword_filter_group.id }

    filtered_entries.each do |filter|
      filter['is_active'] = params[:keyword_filter_group][:is_active]
      redis.hset(redis_key, "#{filter['keyword'].downcase}:#{filter['filter_type']}", filter.to_json)
    end
  end

  def delete_redis_hashtags_by_group_id
    redis = RedisService.client(namespace: 'channel')
    redis_key = KeywordFilterGroup.get_redis_key_name(@keyword_filter_group&.server_setting&.name)
    redis_hash = redis.hgetall(redis_key)
    
    redis_hash.each do |composite_key, json_entry|
      entry = JSON.parse(json_entry)
      if entry['group_id'] == @keyword_filter_group.id
        redis.hdel(redis_key, composite_key)
      end
    end
  end

  def save_to_redis
    redis_key = KeywordFilterGroup.get_redis_key_name(@keyword_filter_group&.server_setting&.name)
    @keyword_filter_group.keyword_filters.each do |keyword_filter|
      KeywordFilterGroup.update_create_redis_filter(redis_key,  keyword_filter.keyword, @keyword_filter_group.server_setting_id, keyword_filter.filter_type, is_active = true, @keyword_filter_group.id, is_custom = true)
    end
  end

  private

  def authorize_keyword_filter_group!
    authorize :keyword_filter_group, "#{action_name}?"
  end
end
