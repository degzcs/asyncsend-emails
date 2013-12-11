#config the mailer and use users for generate the recipient
module Users
  class Service < GenericService

    class << self

      ### ASYNCHRONOUS METHODS ###

      # Used in the controller action for send async transactional emails.
      # @param users_ids [User] are the ids belogs to users selected by performer
      # @param performer [String] is the user responsible for the operation
      # @return ...
      def async_send_templates_to_users(user_ids, performer = nil)
        users = valid_users?(user_ids)
        service_log.info "This user ids could be sent the email \n>> #{users[:valid_user_ids]}"

        user_ids = users[:valid_user_ids]
        if user_ids.present?
          operation = MandrillOperation.create(service: 'Users::Service',
                                               description: 'send template by email',
                                               method_name: 'send_template',
                                               params: {user_ids: user_ids},
                                               performer: performer)
          work_id = MandrillOperationWorker.perform_async(operation.id)
          operation.update_attribute(:work_id, work_id)
        end
        if users[:invalid_user_ids].present?
          service_log.warn "users ids that cannot be sent: because do not have any email address \n>> #{users[:invalid_user_ids]}"
        end
        users[:invalid_user_ids]
      end

      # Send the first user template for a single user
      # @param operation_id [Integer] is the MandrilOperation id, which belong to MandrillSystemOperation will be created
      # @param user_id [Integer] used for extract data for sent in the transactional email
      #  @return ...
      def async_send_template(operation_id, user_id)
        operation = MandrillOperation.find(operation_id)
        system_operation = MandrillSystemOperation.create(params: {user_id: user_id},
                                                          mandrill_operation: operation,
                                                          method_name: 'send_template_to',
                                                          status: 'initiated')
        work_id = MandrillSystemOperationWorker.perform_async(system_operation.id)
        system_operation.update_attribute(:work_id, work_id)
      end

      # This is the high level method that send email for each users
      # @param users [Array] all users selected by the User
      # @return ...
      def send_template(params)
        @users ||= filter_users(params)
        ap params
        @users.each do |user|
          async_send_template(params[:operation_id], user.id)
        end
      end

      # Used for the Worker (MandrillSystemOperationWorker) for send the transactional email with first user template
      # @param params [Hash], keys:
      #                           user_id [Integer]
      # @return  [Array] API mandrill response, on this case onle have one response
      #        API-Response: [Array] of structs for each recipient containing the key "email" with the email address and "status" as either "sent", "queued", or "rejected"
      #         - [Hash] return[] the sending results for a single recipient
      #             - [String] _id the message's unique id
      #             - [String] email the email address of the recipient
      #             - [String] status the sending status of the recipient - either "sent", "queued", "rejected", or "invalid"
      #             - [String] reject_reason the reason for the rejection if the recipient status is "rejected"
      def send_template_to(params)
        ap users = @users.select{|user| user.id.eql? params['user_id']}
        recipient = recipients_from_user(users.first)
        @mailer = Mailer.setup(subject: 'CodeScrum Invitation',
                                              from_name: default_from_name,
                                              from_email: default_from_email,
                                              template: 'Opt In Out Mailing',
                                              global_merge_vars: default_global_merge_vars)
        @mailer.send_one!(recipient)
      end

      # @param users [Array] set of users
      # @return [Array] Recipients group that wrapping a set of users
      def recipients_from_users(users)
        users.map{|user| Users::Recipient.wrap(user)}
      end

      # @return [Hash] with :valid_user_ids (those have email) and :invalid_user_ids(those do not have email)
      def valid_users?(user_ids)
        users = User.find(user_ids)
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

      # @param params [Hash] with all arrears ids selected by Perfomer (current user)
      # @return [Array] Arrears filtered
      def filter_users(params)
        users = User.find(params['user_ids'] )
      end

      # @param users [Array] set of users
      # @return [Array] Recipients group that wrapping a set of users
      def recipients_from_user(user)
        Users::Recipient.wrap(user)
      end

    end
  end
end

