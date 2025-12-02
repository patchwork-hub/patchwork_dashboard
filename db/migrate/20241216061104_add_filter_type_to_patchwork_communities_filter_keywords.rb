class AddFilterTypeToPatchworkCommunitiesFilterKeywords < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_communities_filter_keywords, :filter_type)
      add_column :patchwork_communities_filter_keywords, :filter_type, :string, default: 'filter_out', null: false
    end
  end
end
