class CreatePatchworkJoinedCommunities < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_joined_communities, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true
      t.references :patchwork_community, null: false, foreign_key: true
      t.boolean :is_primary, default: false

      t.timestamps
    end
  end
end