class CreatePatchworkAutoFollows < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_auto_follows, if_not_exists: true do |table|
      table.string :title, null: false
      table.string :instance_name, null: false
      table.boolean :enabled, null: false, default: false
      table.timestamps
    end
    add_index :patchwork_auto_follows, :instance_name, unique: true, if_not_exists: true
  end
end