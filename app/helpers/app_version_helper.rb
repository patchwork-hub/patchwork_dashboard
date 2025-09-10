module AppVersionHelper
  def os_type_android(histories)
    android_history = histories.find { |h| h.os_type == 'android' }
    android_history ? { id: android_history.id, string: '✅' } : { id: nil, string: '❌' }
  end

  def os_type_ios(histories)
    ios_history = histories.find { |h| h.os_type == 'ios' }
    ios_history ? { id: ios_history.id, string: '✅' } : { id: nil, string: '❌' }
  end

  def deprecated_android(histories)
    android_history = histories.find { |h| h.os_type == 'android' }
    android_history ? { id: android_history.id, string: (android_history.deprecated ? '✅' : '❌') } : { id: nil, string: '❌' }
  end

  def deprecated_ios(histories)
    ios_history = histories.find { |h| h.os_type == 'ios' }
    ios_history ? { id: ios_history.id, string: (ios_history.deprecated ? '✅' : '❌') } : { id: nil, string: '❌' }
  end

  def application_name(app_name)
    return 'Patchwork' unless app_name.present?

    app_name_key = AppVersion.app_names.key(app_name.to_i)
    return 'Patchwork' unless app_name_key

    humanized_name = app_name_key.humanize.capitalize
    
    # Check if the instance URL contains "channel" and app is Patchwork
    if humanized_name == 'Patchwork' && is_channel_dashboard?
      'Channels'
    else
      humanized_name
    end
  end
end
