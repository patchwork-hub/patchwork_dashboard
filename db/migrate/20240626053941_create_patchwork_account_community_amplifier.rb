class CreatePatchworkAccountCommunityAmplifier < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_community_amplifiers, if_not_exists: true do |t|
      t.references :account, null: false, foreign_key: true
      t.references :patchwork_community, null: false, foreign_key: true
      t.jsonb :amplifier_settings, null: false, default: {}
      t.boolean :amplifier_turn_on, null: false, default: false
      t.timestamps
    end
    
    unless index_exists?(:patchwork_community_amplifiers, [:account_id, :patchwork_community_id], name: 'index_patchwork_commu_amplifiers_on_account_and_patchwork_commu')
      add_index :patchwork_community_amplifiers, [:account_id, :patchwork_community_id], unique: true, name: 'index_patchwork_commu_amplifiers_on_account_and_patchwork_commu'
    end
  end
end