class CreateKeywordFilters < ActiveRecord::Migration[7.0]
  def change
    create_table :keyword_filters do |t|
      t.string :keyword
      t.integer :filter_type
      t.references :keyword_filter_group, null: false
    end
  end

end
