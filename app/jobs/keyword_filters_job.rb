class KeywordFiltersJob < ApplicationJob
  queue_as :default

  def perform(server_setting_key)
    setting = ServerSetting.by_key(server_setting_key)

    return unless setting

    if setting.value == true
      KeywordFilterGroup.fetch_keyword_filter_group_api(setting.name, setting.id)
    else
      KeywordFilterGroup.delete_all_when_inactive(setting) if KeywordFilterGroup.where(is_custom: false).exists?
    end
  end
end
