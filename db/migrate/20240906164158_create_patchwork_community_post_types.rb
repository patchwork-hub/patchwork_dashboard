class CreatePatchworkCommunityPostTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_community_post_types, if_not_exists: true do |t|
      t.references :patchwork_community, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :posts, null: false, default: false
      t.boolean :reposts, null: false, default: false
      t.boolean :replies, null: false, default: false
      t.timestamps
    end
  end
end
