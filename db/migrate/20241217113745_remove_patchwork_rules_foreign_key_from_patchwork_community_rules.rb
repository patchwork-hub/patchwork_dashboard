class RemovePatchworkRulesForeignKeyFromPatchworkCommunityRules < ActiveRecord::Migration[7.1]
  def change
    if foreign_key_exists?(:patchwork_community_rules, :patchwork_rules)
      remove_foreign_key :patchwork_community_rules, :patchwork_rules
    end
    
    if column_exists?(:patchwork_community_rules, :patchwork_rules_id)
      remove_reference :patchwork_community_rules, :patchwork_rules, foreign_key: false
    end
  end
end