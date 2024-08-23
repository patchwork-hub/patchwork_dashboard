class CreateKeywordFilterGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :keyword_filter_groups do |t|
      t.string :name
      t.boolean :is_custom, default: true
      t.boolean :is_active, default: true
      t.references :server_setting, null: false

      t.timestamps
    end
  end
end
