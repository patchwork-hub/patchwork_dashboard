class AddPostVisibilityToCommunities < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_communities, :post_visibility)
      add_column :patchwork_communities, :post_visibility, :integer, default: 2, null: false
    end
  end
end
