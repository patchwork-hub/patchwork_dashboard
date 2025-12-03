class UpdateIndexOnPatchworkCommunitiesFilterKeywords < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    if index_exists?(:patchwork_communities_filter_keywords, [:keyword, :is_filter_hashtag], name: "index_on_keyword_and_is_filter_hashtag")
      remove_index :patchwork_communities_filter_keywords, name: "index_on_keyword_and_is_filter_hashtag", algorithm: :concurrently
    end
    unless index_exists?(:patchwork_communities_filter_keywords, [:keyword, :is_filter_hashtag, :patchwork_community_id], name: "index_on_keyword_is_filter_hashtag_and_patchwork_community_id")
      add_index :patchwork_communities_filter_keywords,
                [:keyword, :is_filter_hashtag, :patchwork_community_id],
                unique: true,
                name: "index_on_keyword_is_filter_hashtag_and_patchwork_community_id",
                algorithm: :concurrently
    end
  end
end
