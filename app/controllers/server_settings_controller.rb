class ServerSettingsController < ApplicationController
  include ApplicationHelper

  before_action :authorize_server_setting!
  before_action :initialize_server_settings, only: [:index, :branding]

  def index
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

  def branding
    @brand_color.value = site_settings_params[:brand_color]

    %w[mail_header_logo mail_footer_logo].each do |var|
      if site_settings_params.key?(var) && site_settings_params[var].present?
        upload = @site_uploads.find { |s| s.var == var }
        upload.file = site_settings_params[var]
      end
    end

    errors = []
    errors += @brand_color.errors.full_messages unless @brand_color.valid?
    @site_uploads.each { |upload| errors += upload.errors.full_messages unless upload.valid? }

    if errors.any?
      flash.now[:error] = errors.join("<br>")
      render :index, status: :unprocessable_entity
    else
      ActiveRecord::Base.transaction do
        @brand_color.save!
        @site_uploads.each do |upload|
          upload.save! if upload.file.present? && upload.changed?
        end
      end
      redirect_to server_settings_path, notice: "Email Branding updated successfully."
    end
  end

  private

  def initialize_server_settings
    set_keyword_filter_group
    @server_settings = prepare_server_setting

    @site_uploads = %w[mail_header_logo mail_footer_logo].map do |var|
      SiteUpload.find_or_initialize_by(var: var)
    end
    @brand_color = SiteSetting.find_or_initialize_by(var: "brand_color")
  end

  def set_keyword_filter_group
    @keyword_filter_group = KeywordFilterGroup.new
    @keyword_filter_group.keyword_filters.build
  end

  def server_setting_params
    params.require(:server_setting).permit(:value, :optional_value)
  end

  def prepare_server_setting
    @parent_settings = ServerSetting.where(parent_id: nil).order(:id)

    @parent_settings = @parent_settings.where("lower(name) LIKE ?", "%#{@q.downcase}%") if @q.present?

    desired_order = [
      ServerSetting::KEY_LOCAL_FEATURES,
      ServerSetting::KEY_USER_MANAGEMENT,
      ServerSetting::KEY_CONTENT_FILTERS,
      ServerSetting::KEY_SPAM_FILTERS,
      ServerSetting::KEY_FEDERATION,
      ServerSetting::KEY_PLUGINS,
      ServerSetting::KEY_BLUESKY_BRIDGE,
    ]

    base_features = [
      ServerSetting::KEY_SEARCH_OPT_OUT,
      ServerSetting::KEY_LOCAL_ONLY_POSTS,
      ServerSetting::KEY_LONG_POSTS,
      ServerSetting::KEY_BLUESKY_BRIDGE_AUTO,
      ServerSetting::KEY_SPAM_FILTERS,
      ServerSetting::KEY_CONTENT_FILTERS,
    ]

    dashboard_extras = [
      ServerSetting::KEY_CUSTOM_THEME,
      ServerSetting::KEY_GUEST_ACCOUNTS,
      ServerSetting::KEY_ANALYTICS,
      ServerSetting::KEY_LIVE_BLOCKLIST,
      ServerSetting::KEY_SIGNUP_CHALLENGE,
    ]

    desired_child_keys = (is_channel_instance? && is_channel_dashboard?) ? base_features + dashboard_extras : base_features

    @data = @parent_settings.map do |parent_setting|
      child_setting_query = parent_setting.children.where(key: desired_child_keys).sort_by(&:position)
      {
        key: parent_setting.key,
        name: parent_setting.display_name,
        description: parent_setting.setting_description,
        settings: child_setting_query.map do |child_setting|
          {
            id: child_setting.id,
            key: child_setting.key,
            name: child_setting.display_name,
            tooltip: child_setting.tooltip,
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
      desired_index = desired_order.index(item[:key])
      desired_index.nil? ? (desired_order.length + 1) : desired_index
    end

    @data
  end

  def authorize_server_setting!
    authorize :server_setting, "#{action_name}?"
  end

  def site_settings_params
    params.require(:site_settings).permit(:brand_color,:mail_header_logo,:mail_footer_logo)
  end
end
