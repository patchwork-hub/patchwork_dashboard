class AddMuteNotificationTokens < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def self.up
    safety_assured do
      unless column_exists?(:patchwork_notification_tokens, :mute)
        change_table :patchwork_notification_tokens do |t|
          t.boolean :mute, null: false, default: false
        end
      end
    end
  end

  def self.down
    safety_assured do
      if column_exists?(:patchwork_notification_tokens, :mute)
        remove_column :patchwork_notification_tokens, :mute
      end
    end
  end
end