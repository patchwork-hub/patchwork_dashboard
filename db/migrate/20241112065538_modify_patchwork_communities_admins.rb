class ModifyPatchworkCommunitiesAdmins < ActiveRecord::Migration[7.1]
  def change
    def change
      safety_assured { remove_reference :patchwork_communities_admins, :account, foreign_key: true }
    end

    unless column_exists?(:patchwork_communities_admins, :display_name)
      add_column :patchwork_communities_admins, :display_name, :string
    end
    unless column_exists?(:patchwork_communities_admins, :email)
      add_column :patchwork_communities_admins, :email, :string
    end
    unless column_exists?(:patchwork_communities_admins, :username)
      add_column :patchwork_communities_admins, :username, :string
    end
    unless column_exists?(:patchwork_communities_admins, :password)
      add_column :patchwork_communities_admins, :password, :string
    end
  end
end
