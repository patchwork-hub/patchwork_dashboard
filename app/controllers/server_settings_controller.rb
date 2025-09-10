class ServerSettingsController < ApplicationController
  before_action :authorize_master_admin!
  before_action :set_keyword_filter_group, only: [:index]

  def index
    @server_settings = prepare_server_setting
  end

  def update
    @server_setting = ServerSetting.find(params[:id])

    if @server_setting.update(server_setting_params)
      render json: { success: true, message: 'Server setting updated successfully' }
    else
      render json: { success: false, error: 'Failed to update server setting' }, status: :unprocessable_entity
    end
  end

  def group_data
    server_setting_id = params[:server_setting_id]
    @existing_data = KeywordFilterGroup.where(server_setting_id: server_setting_id).where(is_custom: true).order(:id).pluck(:name)
    render json: @existing_data
  end

  private

  def set_keyword_filter_group
    @keyword_filter_group = KeywordFilterGroup.new
    @keyword_filter_group.keyword_filters.build
  end

  def server_setting_params
    params.require(:server_setting).permit(:value, :optional_value)
  end

  def prepare_server_setting
    @parent_settings = ENV['MASTODON_INSTANCE_URL']&.include?('channel') ? ServerSetting.where(parent_id: nil).includes(:children).order(:id) : ServerSetting.where(parent_id: nil).order(:id)

    @parent_settings = @parent_settings.where("lower(name) LIKE ?", "%#{@q.downcase}%") if @q.present?

    desired_order = ['Local Features', 'User Management', 'Content filters', 'Spam filters', 'Federation', 'Plug-ins']
    desired_child_name = ['Spam filters', 'Content filters', 'Bluesky', 'Search opt-out', 'Long posts and markdown', 'e-Newsletters']

    @data = @parent_settings.map do |parent_setting|
      child_setting_query = ENV['MASTODON_INSTANCE_URL']&.include?('channel') ? parent_setting.children.sort_by(&:position) : parent_setting.children.where(name: desired_child_name).sort_by(&:position)
      {
        name: parent_setting.name,
        settings: child_setting_query.map do |child_setting|
          {
            id: child_setting.id,
            name: child_setting.name,
            is_operational: child_setting.value,
            optional_value: child_setting.optional_value,
            keyword_filter_groups: child_setting.keyword_filter_groups.order(name: :asc).map do |group|
              {
                id: group.id,
                name: group.name,
                is_custom: group.is_custom,
                is_active: group.is_active
              }
            end
          }
        end
      }
    end

    @data.sort_by! do |item|
      desired_index = desired_order.index(item[:name])
      desired_index.nil? ? (desired_order.length + 1) : desired_index
    end

    @data
  end

  def authorize_master_admin!
    authorize :master_admin, :index?
  end
end
