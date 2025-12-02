class AddRoleToCommunityAdmins < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_communities_admins, :role)
      add_column :patchwork_communities_admins, :role, :string
    end
  end
end
