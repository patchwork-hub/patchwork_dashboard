class CreatePostHashtagsCommunity < ActiveRecord::Migration[7.1]
  def change
    create_table :post_hashtags_communities, if_not_exists: true do |t|
      t.references :patchwork_community, null: false, foreign_key: true
      t.string :hashtag
      t.timestamps
    end
  end
end
