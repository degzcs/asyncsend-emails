#config the mailer and use users for generate the recipient
module Users
  class Service < GenericService

    class << self

      ### ASYNCHRONOUS METHODS ###

      # Used in the controller action for send async transactional emails.
      # @param users_ids [User] are the ids belogs to users selected by performer
      # @param performer [String] is the user responsible for the operation
      # @return ...
      def async_send_user_templates(user_ids, performer = nil)
        users = valid_users?(user_ids)
        service_log.info 'This user ids could be sent the email'
        service_log.info ">> #{users[:valid_user_ids]}"

        user_ids = users[:valid_user_ids]
        if user_ids.present?
          operation = MandrillOperation.create(service: 'SpaceMandrill::users::Service',
                                               description: I18n.t(:send_users_letters_by_email),
                                               method_name: 'send_user_letters',
                                               params: {user_ids: user_ids},
                                               performer: performer)
          work_id = MandrillOperationWorker.perform_async(operation.id)
          operation.update_attribute(:work_id, work_id)
        end
        if users[:invalid_user_ids].present?
          service_log.warn 'users ids that cannot be sent: because do not have any email address'
          service_log.warn ">> #{users[:invalid_user_ids]}"
        end
        users[:invalid_user_ids]
      end

      # Send the first user letter for a single user
      # @param operation_id [Integer] is the MandrilOperation id, which belong to MandrillSystemOperation will be created
      # @param user_id [Integer] used for extract data for sent in the transactional email
      #  @return ...
      def async_send_first_user_letter(operation_id, user_id)
        operation = MandrillOperation.find(operation_id)
        system_operation = MandrillSystemOperation.create(params: {user_id: user_id},
                                                          mandrill_operation: operation,
                                                          method_name: 'send_first_user_letter_to',
                                                          status: 'initiated')
        work_id = MandrillSystemOperationWorker.perform_async(system_operation.id)
        system_operation.update_attribute(:work_id, work_id)
      end

      # Send the second user letter for a single user
      # @param operation_id [Integer] is the MandrilOperation id, which belong to MandrillSystemOperation will be created
      # @param user_id [Integer] used for extract data for sent in the transactional email
      #  @return ...
      def async_send_second_user_letter(operation_id, user_id)
        operation = MandrillOperation.find(operation_id)
        system_operation = MandrillSystemOperation.create(params: {user_id: user_id},
                                                          mandrill_operation: operation,
                                                          method_name: 'send_second_user_letter_to',
                                                          status: 'initiated')
        work_id = MandrillSystemOperationWorker.perform_async(system_operation.id)
        system_operation.update_attribute(:work_id, work_id)
      end

      # Update all mandrill templates with the Rap styles, this styles are used mainly for display the transactions table
      # @return worker id
      def async_update_templates
        UpdateMandrillTemplatesWorker.perform_async(:users)
      end

      # Sent a email to the current user logged with the user information related with the selected user
      # @param performer [User] Current user logged
      # @param tenant_id [Integer] User Id selected
      def async_send_test_templates(performer, tenant_id)
        email =  performer.primary_email_value
        SendTestMandrillTemplatesWorker.perform_async(:users, email, tenant_id)
      end

      # This is the high level method that send email for each users
      # @param users [Array] all users selected by the User
      # @return ...
      def send_user_letters(params)
        @users ||= filter_users(params)
        first_letter_users = filter_first_letter_users(@users)
        second_letter_users = filter_second_letter_users(@users)

        first_letter_users.each do |user|
          async_send_first_user_letter(params[:operation_id], user.id)
        end

        second_letter_users.each do |user|
          async_send_second_user_letter(params[:operation_id], user.id)
        end
      end

      # Used for the Worker (MandrillSystemOperationWorker) for send the transactional email with first user letter
      # @param params [Hash], keys:
      #                           user_id [Integer]
      # @return  [Array] API mandrill response, on this case onle have one response
      #        API-Response: [Array] of structs for each recipient containing the key "email" with the email address and "status" as either "sent", "queued", or "rejected"
      #         - [Hash] return[] the sending results for a single recipient
      #             - [String] _id the message's unique id
      #             - [String] email the email address of the recipient
      #             - [String] status the sending status of the recipient - either "sent", "queued", "rejected", or "invalid"
      #             - [String] reject_reason the reason for the rejection if the recipient status is "rejected"
      def send_first_user_letter_to(params)
        users = @users.select{|user| user.id.eql? params[:user_id]}
        recipient = recipients_from_user(users.first)
        @mailer = SpaceMandrill::Mailer.setup(subject: 'SPACE - Rent Notice (1)',
                                              from_name: default_from_name,
                                              from_email: default_from_email,
                                              template: 'first_users_letter_template',
                                              global_merge_vars: default_global_merge_vars)
        @mailer.send_one!(recipient)
      end

      # Used for the Worker (MandrillSystemOperationWorker) for send the transactional email with second user letter
      # @param params [Hash], keys:
      #                           user_id [Integer]
      # @return  [Array] API mandrill response, on this case onle have one response
      #        API-Response: [Array] of structs for each recipient containing the key "email" with the email address and "status" as either "sent", "queued", or "rejected"
      #         - [Hash] return[] the sending results for a single recipient
      #             - [String] _id the message's unique id
      #             - [String] email the email address of the recipient
      #             - [String] status the sending status of the recipient - either "sent", "queued", "rejected", or "invalid"
      #             - [String] reject_reason the reason for the rejection if the recipient status is "rejected"
      def send_second_user_letter_to(params)
        users = @users.select{|user| user.id.eql? params[:user_id]}
        recipient = recipients_from_user(users.first)
        @mailer = SpaceMandrill::Mailer.setup(subject: 'SPACE - Rent Notice (2)',
                                              from_name: default_from_name,
                                              from_email: default_from_email,
                                              template: 'second_users_letter_template',
                                              global_merge_vars: default_global_merge_vars)
        @mailer.send_one!(recipient)
      end

      # @param params [Hash] with all users ids selected by Perfomer (current user)
      # @return [Array] users filtered
      def filter_users(params)
        users = user.positive_users.where(:id => params[:user_ids] )
        filter_activated_service_users(users)
      end
      # @param users [Array] set of users
      # @return [Array] users group to which they will send the first letter
      def filter_first_letter_users(users)
        users.select{|user|  user.have_to_send_first_letter?}
      end

      # @param users [Array] set of users
      # @return [Array] users group to which they will send the second letter
      def filter_second_letter_users(users)
        users.reject{|user|  user.have_to_send_first_letter?}
      end

      # @param users [Array]
      # @return [Array] with all users who activated the service for send letters by email
      def filter_activated_service_users(users)
        deactivated_service_users = filter_deactivated_service_users(users)
        if deactivated_service_users.present?
          service_log.warn 'users ids that cannot be sent: because they were deactivated this option'
          service_log.warn ">> #{deactivated_service_users}"
        end
        users.select{|user| user.can_emailing?}
      end

      # @param users [Array]
      # @return [Array] with all users who deactivated the service for send letters by email
      def filter_deactivated_service_users(users)
        users.reject{|user| user.can_emailing?}.map(&:id)
      end

      # @param users [Array] set of users
      # @return [Array] Recipients group that wrapping a set of users
      def recipients_from_users(users)
        users.map{|user| SpaceMandrill::users::Recipient.wrap(user)}
      end

      # @return [Hash] with :valid_user_ids (those have email) and :invalid_user_ids(those do not have email)
      def valid_users?(user_ids)
        users = user.positive_users.where(:id => user_ids)
        {valid_user_ids: valid_user_ids(users), invalid_user_ids: invalid_user_ids(users)}
      end

      # @param users set of user Users
      # @return [Array] with all user users that haven't email
      def invalid_user_ids(users)
        users.reject{|user| has_email?(user)}.map(&:id)
      end

      # @param users set of user Users
      # @return [Array] with all user users that have email
      def valid_user_ids(users)
        users.select{|user| has_email?(user)}.map(&:id)
      end

      # @param users [Array] set of users
      # @return [Array] Recipients group that wrapping a set of users
      def recipients_from_user(user)
        SpaceMandrill::users::Recipient.wrap(user)
      end

      # @param recipients [Recipient]
      # @param test_email [String]
      # @return [Recipient]
      def replace_recipient_emails(recipients, test_email)
        recipients.map do |recipient|
          recipient.to[:email] = test_email
          recipient.merge_vars[:rcpt] = test_email
          recipient
        end
      end
    end
  end
end

