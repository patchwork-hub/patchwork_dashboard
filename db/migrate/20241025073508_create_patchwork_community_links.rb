class CreatePatchworkCommunityLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_community_links, if_not_exists: true do |t|
      t.string :icon
      t.string :name
      t.string :url
      t.references :patchwork_community, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
  end
end
