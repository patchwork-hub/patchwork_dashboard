class RemoveIndexAndMakeAccountNullableInPatchworkCommunitiesAdmins < ActiveRecord::Migration[7.1]
  def change
    if index_exists?(:patchwork_communities_admins, [:account_id, :patchwork_community_id], name: 'index_patchwork_communities_admins_on_account_and_community')
      remove_index :patchwork_communities_admins, name: 'index_patchwork_communities_admins_on_account_and_community'
    end

    if column_exists?(:patchwork_communities_admins, :account_id)
      change_column_null :patchwork_communities_admins, :account_id, true
    end
  end
end