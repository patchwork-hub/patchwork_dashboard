class RemoveAccountFromPatchworkCommunitiesFilterKeywords < ActiveRecord::Migration[7.1]
  def change
    safety_assured do
      if foreign_key_exists?(:patchwork_communities_filter_keywords, :accounts)
        remove_foreign_key :patchwork_communities_filter_keywords, :accounts
      end
      
      if column_exists?(:patchwork_communities_filter_keywords, :account_id)
        remove_column :patchwork_communities_filter_keywords, :account_id
      end
      
      if index_exists?(:patchwork_communities_filter_keywords, :account_id)
        remove_index :patchwork_communities_filter_keywords, :account_id
      end
    end
  end
end