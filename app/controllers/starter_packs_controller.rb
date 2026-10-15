class StarterPacksController < ApplicationController
  before_action :authorize_starter_pack!
  before_action :set_starter_pack, except: %i[index new create search_accounts next_position reorder]

  def index
    @search = StarterPack.ransack(params[:q])
    @records = @search.result.includes(:created_by).order(:instance_name, :position, :id).page(params[:page]).per(20)
    @total_accounts = StarterPackAccount.where(patchwork_starter_pack_id: @records.map(&:id)).group(:patchwork_starter_pack_id).count
  end

  def new
    @starter_pack = StarterPack.new(instance_name: params[:instance_name])
    @starter_pack.position = StarterPack.next_position_for(@starter_pack.instance_name)
  end

  def next_position
    render json: { position: StarterPack.next_position_for(params[:instance_name]) }
  end

  def create
    @starter_pack = StarterPack.new(starter_pack_params)
    if @starter_pack.save
      redirect_to @starter_pack, notice: 'Starter pack created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @members = @starter_pack.starter_pack_accounts.includes(:account).load
  end

  def edit
  end

  def update
    if @starter_pack.update(starter_pack_params)
      redirect_to @starter_pack, notice: 'Starter pack updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @starter_pack.destroy!
    redirect_to starter_packs_path, notice: 'Starter pack deleted.'
  end

  def search_accounts
    accounts = StarterPackAccountSearchService.new(params[:query], user: current_user).call
    render json: { accounts: accounts }
  rescue StarterPackAccountSearchService::SearchError
    render json: { error: 'Account search is unavailable. Please try again.' }, status: :bad_gateway
  end

  def add_account
    account = Account.find(params.require(:account_id))
    @starter_pack.with_lock do
      @starter_pack.starter_pack_accounts.find_or_create_by!(account: account) do |membership|
        membership.position = (@starter_pack.starter_pack_accounts.maximum(:position) || -1) + 1
      end
    end
    head :no_content
  end

  def remove_account
    @starter_pack.with_lock do
      @starter_pack.starter_pack_accounts.find_by!(account_id: params.require(:account_id)).destroy!
    end
    head :no_content
  end

  def reorder
    StarterPack.with_order_lock do
      packs = StarterPack.for_instance(params.require(:instance_name)).order(:id).lock.to_a
      temporary_position = [packs.map(&:position).max || 0, packs.size].max + 1
      packs.each_with_index { |pack, index| pack.update!(position: temporary_position + index) }
      apply_order!(packs, params.require(:ids), start_position: 1)
    end
    head :no_content
  rescue ArgumentError
    render json: { error: 'Provide every pack in this instance exactly once.' }, status: :unprocessable_entity
  end

  def reorder_accounts
    @starter_pack.with_lock do
      apply_order!(@starter_pack.starter_pack_accounts.to_a, params.require(:ids))
    end
    head :no_content
  rescue ArgumentError
    render json: { error: 'Provide every membership in this pack exactly once.' }, status: :unprocessable_entity
  end

  private

  def apply_order!(records, ids, start_position: 0)
    raise ArgumentError unless ids.is_a?(Array)

    ids = ids.map(&:to_s)
    raise ArgumentError unless ids.sort == records.map { |record| record.id.to_s }.sort

    by_id = records.index_by { |record| record.id.to_s }
    ids.each_with_index { |id, position| by_id.fetch(id).update!(position: position + start_position) }
  end

  def starter_pack_params
    params.require(:starter_pack).permit(:title, :description, :instance_name, :created_by_id, :position)
  end

  def set_starter_pack
    @starter_pack = StarterPack.find(params[:id])
  end

  def authorize_starter_pack!
    authorize :starter_pack, "#{action_name}?"
  end
end