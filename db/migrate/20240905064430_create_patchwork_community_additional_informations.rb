class CreatePatchworkCommunityAdditionalInformations < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_community_additional_informations, if_not_exists: true do |t|
      t.string :heading
      t.text :text
      t.references :patchwork_community, null: false, foreign_key: { to_table: :patchwork_communities, on_delete: :cascade }

      t.timestamps
    end
  end
end
