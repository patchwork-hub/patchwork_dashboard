class RemoveUnneededIndexes < ActiveRecord::Migration[7.1]
  def change
    if index_exists?(:patchwork_communities_admins, :account_id, name: "index_patchwork_communities_admins_on_account_id")
      remove_index :patchwork_communities_admins, name: "index_patchwork_communities_admins_on_account_id", column: :account_id
    end
    if index_exists?(:patchwork_communities_hashtags, :patchwork_community_id, name: "index_patchwork_communities_hashtags_on_patchwork_community_id")
      remove_index :patchwork_communities_hashtags, name: "index_patchwork_communities_hashtags_on_patchwork_community_id", column: :patchwork_community_id
    end
    if index_exists?(:patchwork_communities_statuses, :status_id, name: "index_patchwork_communities_statuses_on_status_id")
      remove_index :patchwork_communities_statuses, name: "index_patchwork_communities_statuses_on_status_id", column: :status_id
    end
    if index_exists?(:patchwork_community_amplifiers, :account_id, name: "index_patchwork_community_amplifiers_on_account_id")
      remove_index :patchwork_community_amplifiers, name: "index_patchwork_community_amplifiers_on_account_id", column: :account_id
    end
  end
end
