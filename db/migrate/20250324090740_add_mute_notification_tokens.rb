class AddMuteNotificationTokens < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def self.up
    unless column_exists?(:patchwork_notification_tokens, :mute)
      add_column :patchwork_notification_tokens, :mute, :boolean, null: false, default: false
    end
  end

  def self.down
    if column_exists?(:patchwork_notification_tokens, :mute)
      safety_assured { remove_column :patchwork_notification_tokens, :mute }
    end
  end
end