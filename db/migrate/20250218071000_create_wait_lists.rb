class CreateWaitLists < ActiveRecord::Migration[7.1]
  def change
    create_table :patchwork_wait_lists, if_not_exists: true do |t|
      t.text :email
      t.text :description
      t.text :invitation_code, null: false, index: { unique: true }
      t.boolean :used, default: false
      t.timestamps
    end
  end
end
