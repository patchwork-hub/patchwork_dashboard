class CreatePatchworkStarterPacks < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_starter_packs, if_not_exists: true do |table|
      table.string :title, null: false
      table.text :description
      table.string :instance_name, null: false
      table.references :created_by, foreign_key: { to_table: :accounts, on_delete: :nullify }
      table.integer :position, null: false, default: 0
      table.timestamps
    end
    add_index :patchwork_starter_packs, [:instance_name, :position], if_not_exists: true
  end
end