class CreateKeywordFilterGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :keyword_filter_groups, if_not_exists: true do |t|
      t.string :name
      t.boolean :is_custom, default: true
      t.boolean :is_active, default: true
      t.references :server_setting, null: false, foreign_key: { on_delete: :cascade }

      t.timestamps
    end
  end
end
