class MakePatchworkCommunityIdNullableInFilterKeywords < ActiveRecord::Migration[7.1]
  def change
    change_column_null :patchwork_communities_filter_keywords, :patchwork_community_id, true
  end
end
