class AccountsController < ApplicationController
  before_action :get_selecte_and_unselected, only: [:index, :export]
  load_and_authorize_resource

  def index
    respond_to do |format|
      format.html
      format.json {render json: prepare_users_for_datatable}
    end
  end

  def show; end

  def export
    if request.post?
      if params[:email].present?
        ExportExcelJob.perform_later email: params[:email], type: 'user', selected: @selected, unselected: @unselected, q: params[:q]

        redirect_to accounts_url, notice: 'The export of all users is in process. The system will send you an email that you provided with a download link when it is ready.'
      else
        flash[:error] = 'Please fill out email field.'
        render :export
      end
    end
  end

  private

    def prepare_users_for_datatable
      @all   = Account.get_accounts
      @users = @all
      
      if @q.present?
        @users = @users.where("   lower(accounts.display_name) like :q
                                  OR lower(accounts.username) like :q
                                  OR lower(users.email) like :q
                                  OR lower(users.phone) like :q
                                  OR lower(mammoth_wait_lists.role) like :q
                                  OR lower(mammoth_communities.name) like :q",
                                  q: "%#{@q.downcase}%"
                                )
      end
      @users = @users.order("#{@sort}": :"#{@dir}").uniq
      @all   = @all.uniq
      
      @users = Kaminari.paginate_array(@users).page(@page).per(@per)

      @data = @users.each_with_object([]) { |u, arr|
        if @selected == 'all'
          checked = !@unselected.map(&:to_i).include?(u.id)
        else
          checked = @selected.map(&:to_i).include?(u.id)
        end
        arr << {
          id: "<input type='checkbox' class='mx-auto mt-1 form-check checkbox' value='#{u.id}' id='user-#{u.id}' #{checked ? 'checked' : ''}>",
          username: u.username,
          email: u.phone.present? ? '-' : u.email,
          phone: u.phone || '-',
          registered_at: u.registered_at.strftime('%b %d, %Y - %H:%M %p'),
          user_role: u.user_role,
          community_name: u.community_name.presence || '-',
          actions: "
                    <a href='#{account_url(u.account_id)}' title='view report' class='mr-2'><i class='fa-solid fa-eye'></i></a>
                  "
        }
      }

      total_records  = @all.size
      total_filtered = @q.present? ? @users.total_count : total_records

      {draw: params[:draw], recordsTotal: total_records, recordsFiltered: total_filtered, data: @data}
    end

    def get_selecte_and_unselected
      @selected    = params[:selected]
      unless @selected == 'all'
        unless @selected.is_a?(Array)
          @selected  = @selected.to_s.split(',')
        end
      end

      @unselected    = params[:unselected]
      unless @unselected.is_a? Array
        @unselected  = @unselected.to_s.split(',')
      end
    end

end

