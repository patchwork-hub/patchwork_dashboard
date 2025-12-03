class AddDeletedAtToChannelsAndCommunities < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_communities, :deleted_at)
      add_column :patchwork_communities, :deleted_at, :datetime
    end
  end
end
