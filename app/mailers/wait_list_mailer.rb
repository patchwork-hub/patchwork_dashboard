class WaitListMailer < ActionMailer::Base
  default from: %{Patchwork <#{ENV['SMTP_FROM_ADDRESS']}>}
  layout 'email'

  def send_invitation_code
    if params[:email].present? && params[:invitation_code].present?
      @email = params[:email]
      @invitation_code = params[:invitation_code]
      @subject = I18n.t('mailers.wait_list.send_invitation_code.subject')
      mail(to: params[:email], subject: @subject)
    end
  end
end