class CreatePatchworkCommunityRules < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_community_rules, if_not_exists: true do |t|
      t.references :patchwork_community, null: false, foreign_key: true
      # t.references :patchwork_rules, null: false, foreign_key: true
      t.timestamps
    end
  end
end
