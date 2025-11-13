class AddNoBoostChannelToCommunity < ActiveRecord::Migration[7.1]
  def change
    add_column :patchwork_communities, :no_boost_channel, :boolean, default: false
  end
end
