class AutoFollowsController < ApplicationController
  before_action :authorize_auto_follow!
  before_action :set_auto_follow, except: %i[index new create search_accounts]

  def index
    @search = AutoFollow.ransack(params[:q])
    @records = @search.result.order(:instance_name, :id).page(params[:page]).per(20)
    @total_accounts = AutoFollowAccount.where(patchwork_auto_follow_id: @records.map(&:id)).group(:patchwork_auto_follow_id).count
  end

  def new
    @auto_follow = AutoFollow.new
    @members = []
  end

  def create
    attributes = auto_follow_params
    account_ids = Array(attributes.delete(:account_ids)).reject(&:blank?).map(&:to_s).uniq
    @auto_follow = AutoFollow.new(attributes)
    build_auto_follow_accounts(account_ids)
    if @auto_follow.save
      redirect_to @auto_follow, notice: 'Auto-follow created.'
    else
      @members = @auto_follow.auto_follow_accounts.to_a
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @members = @auto_follow.auto_follow_accounts.reorder(created_at: :desc, id: :desc).includes(:account).load
  end

  def edit
    @members = @auto_follow.auto_follow_accounts.reorder(created_at: :desc, id: :desc).includes(:account).load
  end

  def update
    attributes = auto_follow_params
    remove_account_id = attributes.delete(:remove_account_id).to_s
    account_ids = if attributes.key?(:account_ids)
      Array(attributes.delete(:account_ids)).reject(&:blank?).map(&:to_s).uniq
    else
      @auto_follow.auto_follow_accounts.pluck(:account_id).map(&:to_s)
    end
    account_ids.delete(remove_account_id) if remove_account_id.present?
    updated = false
    @auto_follow.transaction do
      replace_auto_follow_accounts(account_ids)
      updated = @auto_follow.update(attributes)
      raise ActiveRecord::Rollback unless updated
    end

    if updated
      if remove_account_id.present?
        redirect_to edit_auto_follow_path(@auto_follow), notice: 'Account removed.'
      else
        redirect_to @auto_follow, notice: 'Auto-follow updated.'
      end
    else
      @members = @auto_follow.auto_follow_accounts.reload.includes(:account).to_a
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @auto_follow.destroy!
    redirect_to auto_follows_path, notice: 'Auto-follow deleted.'
  end

  def search_accounts
    accounts = StarterPackAccountSearchService.new(params[:query], user: current_user).call
    render json: { accounts: accounts }
  rescue StarterPackAccountSearchService::SearchError
    render json: { error: 'Account search is unavailable. Please try again.' }, status: :bad_gateway
  end

  def add_account
    account = Account.find(params.require(:account_id))
    @auto_follow.with_lock do
      @auto_follow.auto_follow_accounts.find_or_create_by!(account: account) do |membership|
        membership.position = (@auto_follow.auto_follow_accounts.maximum(:position) || -1) + 1
      end
    end
    head :no_content
  end

  def remove_account
    last_account_blocked = false
    @auto_follow.with_lock do
      membership = @auto_follow.auto_follow_accounts.find_by!(account_id: params.require(:account_id))
      last_account_blocked = @auto_follow.enabled? && @auto_follow.auto_follow_accounts.count == 1
      membership.destroy! unless last_account_blocked
    end
    if last_account_blocked
      render json: { error: 'An enabled auto-follow list must contain at least one account.' }, status: :unprocessable_entity
    else
      head :no_content
    end
  end

  def reorder_accounts
    @auto_follow.with_lock do
      apply_order!(@auto_follow.auto_follow_accounts.to_a, params.require(:ids))
    end
    head :no_content
  rescue ArgumentError
    render json: { error: 'Provide every membership in this auto-follow exactly once.' }, status: :unprocessable_entity
  end

  def toggle_enabled
    if @auto_follow.update(enabled: ActiveModel::Type::Boolean.new.cast(params.require(:enabled)))
      render json: { enabled: @auto_follow.enabled }
    else
      render json: { error: @auto_follow.errors[:enabled].first }, status: :unprocessable_entity
    end
  end

  private

  def apply_order!(records, ids)
    raise ArgumentError unless ids.is_a?(Array)

    ids = ids.map(&:to_s)
    raise ArgumentError unless ids.sort == records.map { |record| record.id.to_s }.sort

    by_id = records.index_by { |record| record.id.to_s }
    ids.each_with_index { |id, position| by_id.fetch(id).update!(position: position) }
  end

  def auto_follow_params
    params.require(:auto_follow).permit(:title, :instance_name, :enabled, :remove_account_id, account_ids: [])
  end

  def build_auto_follow_accounts(account_ids)
    accounts_by_id = Account.where(id: account_ids).index_by { |account| account.id.to_s }
    account_ids.each_with_index do |account_id, position|
      account = accounts_by_id[account_id]
      @auto_follow.auto_follow_accounts.build(account: account, position: position) if account
    end
  end

  def replace_auto_follow_accounts(account_ids)
    accounts_by_id = Account.where(id: account_ids).index_by { |account| account.id.to_s }
    @auto_follow.auto_follow_accounts.destroy_all
    @auto_follow.association(:auto_follow_accounts).reset
    account_ids.each_with_index do |account_id, position|
      account = accounts_by_id[account_id]
      @auto_follow.auto_follow_accounts.create!(account: account, position: position) if account
    end
  end

  def set_auto_follow
    @auto_follow = AutoFollow.find(params[:id])
  end

  def authorize_auto_follow!
    authorize :auto_follow, "#{action_name}?"
  end
end