class AddIsBoostBotToCommunityAdmin < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_communities_admins, :is_boost_bot)
      add_column :patchwork_communities_admins, :is_boost_bot, :boolean, default: false, null: false
    end
  end
end
