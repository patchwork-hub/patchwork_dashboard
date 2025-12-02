class AddAboutToCommunities < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_communities, :about)
      add_column :patchwork_communities, :about, :string
    end
  end
end
