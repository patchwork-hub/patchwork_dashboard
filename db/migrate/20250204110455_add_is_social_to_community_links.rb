class AddIsSocialToCommunityLinks < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_community_links, :is_social)
      add_column :patchwork_community_links, :is_social, :boolean, default: false
    end
  end
end
