class CreateServerSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :server_settings, if_not_exists: true do |t|
      t.string :name
      t.string :optional_value
      t.boolean :value
      t.integer :position
      t.bigint :parent_id, null: true
      t.datetime :deleted_at
      t.timestamps
    end
  end

end
