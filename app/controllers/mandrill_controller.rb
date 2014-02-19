class MandrillController < ApplicationController
  def webhook
    if params[:mandrill_events].present?
      params_json = JSON.parse(params[:mandrill_events], :symbolize_names => true)
      params_json.each do |mandrill_event|
        change_mandrill_system_operation_status(mandrill_event)
        ##for now in any event is saved into the MandrillSystemOperation state
        #event = mandrill_event[:event]
        #case event
        #when 'send'
        #    change_mandrill_system_operation_status(mandrill_event)
        #  when 'deferral'
        #    #unsubscribe_user
        #  when 'hard_bounce'
        #    #user_profile_update
        #  when 'soft_bounce'
        #    #user_email_update
        #  when 'open'
        #    #clean_user
        #  when 'click'
        #    #clean_user
        #  when 'spam'
        #    #clean_user
        #  when 'unsub'
        #    #clean_user
        #  when 'reject'
        #    #clean_user
        #  else
        #    head 200
        #end
      end
    else
      head 200
    end

  end

  # send email to all current active tenants
  def send_user_email
    #ap params[:emailing]
    flash[:notice] = "sending mails ..."
    SendEmailMandrill::Users::Service.async_send_templates_to_users(params[:emailing][:user_ids])
    redirect_to :back
  end

  private
  def change_mandrill_system_operation_status(mandrill_event)
    if mandrill_event[:msg].present?
      system_operation = MandrillSystemOperation.find_by_mandrill_id(mandrill_event[:msg][:_id])
      if system_operation.update_attribute(:status, mandrill_event[:msg][:state])
        head 200
      else
        render text: system_operation.errors.full_messages.join(',')
      end
    end
  end
end
