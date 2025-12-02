class AddRuleToPatchworkCommunityRules < ActiveRecord::Migration[7.1]
  def change
    unless column_exists?(:patchwork_community_rules, :rule)
      add_column :patchwork_community_rules, :rule, :string
    end
  end
end
