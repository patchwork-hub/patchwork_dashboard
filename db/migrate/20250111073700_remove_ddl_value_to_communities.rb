class RemoveDdlValueToCommunities < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :patchwork_communities, :ddl_value }
    unless column_exists?(:patchwork_communities, :did_value)
      add_column :patchwork_communities, :did_value, :string, default: nil, null: true
    end
  end
end
