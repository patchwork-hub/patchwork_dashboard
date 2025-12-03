class CreatePatchworkCommunitiesAdmins < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_communities_admins, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true
      t.references :patchwork_community, null: false, foreign_key: true
      t.timestamps
    end

    unless index_exists?(:patchwork_communities_admins, [:account_id, :patchwork_community_id], name: 'index_patchwork_communities_admins_on_account_and_community')
      add_index :patchwork_communities_admins, [:account_id, :patchwork_community_id], unique: true, name: 'index_patchwork_communities_admins_on_account_and_community'
    end
  end
end
