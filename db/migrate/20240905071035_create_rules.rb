class CreateRules < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_rules, if_not_exists: true do |t|
      t.text :description
      t.timestamps
    end
  end
end
