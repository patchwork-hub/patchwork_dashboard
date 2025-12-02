class CreateKeywordFilters < ActiveRecord::Migration[7.0]
  def change
    create_table :keyword_filters, if_not_exists: true do |t|
      t.string :keyword
      t.integer :filter_type
      t.references :keyword_filter_group, null: false, foreign_key: { on_delete: :cascade }
    end
  end
end
