class AddChannelTypeToCommunities < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_communities, :channel_type)
      add_column :patchwork_communities, :channel_type, :string, default: 'channel', null: false
    end
  end
end
