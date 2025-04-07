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
end
