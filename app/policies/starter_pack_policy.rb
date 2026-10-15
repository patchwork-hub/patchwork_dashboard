class StarterPackPolicy < ApplicationPolicy
  def index?
    master_admin? || can?(:manage_starter_packs)
  end

  alias_method :show?, :index?
  alias_method :create?, :index?
  alias_method :update?, :index?
  alias_method :destroy?, :index?
  alias_method :search_accounts?, :index?
  alias_method :next_position?, :index?
  alias_method :add_account?, :index?
  alias_method :remove_account?, :index?
  alias_method :reorder?, :index?
  alias_method :reorder_accounts?, :index?
end