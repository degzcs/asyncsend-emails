#config the mailer and use csv contacts for generate the recipient
module Contacts
  class Service < GenericService

    class << self

      ### ASYNCHRONOUS METHODS ###

      # Used in the controller action for send async transactional emails.
      # @param users_ids [User] are the ids belogs to arrears selected by performer
      # @param performer [String] is the user responsible for the operation
      # @return ...
      def async_send_arrear_letters(arrear_ids, performer = nil)
        arrears = valid_arrears?(arrear_ids)
        service_log.info 'This arrear ids could be sent the email'
        service_log.info ">> #{arrears[:valid_arrear_ids]}"

        arrear_ids = arrears[:valid_arrear_ids]
        if arrear_ids.present?
          operation = MandrillOperation.create(service: 'SpaceMandrill::Arrears::Service',
                                               description: I18n.t(:send_arrears_letters_by_email),
                                               method_name: 'send_arrear_letters',
                                               params: {arrear_ids: arrear_ids},
                                               performer: performer)
          work_id = MandrillOperationWorker.perform_async(operation.id)
          operation.update_attribute(:work_id, work_id)
        end
        if arrears[:invalid_arrear_ids].present?
          service_log.warn 'Arrears ids that cannot be sent: because do not have any email address'
          service_log.warn ">> #{arrears[:invalid_arrear_ids]}"
        end
        arrears[:invalid_arrear_ids]
      end

      # Send the first arrear letter for a single arrear
      # @param operation_id [Integer] is the MandrilOperation id, which belong to MandrillSystemOperation will be created
      # @param arrear_id [Integer] used for extract data for sent in the transactional email
      #  @return ...
      def async_send_first_arrear_letter(operation_id, arrear_id)
        operation = MandrillOperation.find(operation_id)
        system_operation = MandrillSystemOperation.create(params: {arrear_id: arrear_id},
                                                          mandrill_operation: operation,
                                                          method_name: 'send_first_arrear_letter_to',
                                                          status: 'initiated')
        work_id = MandrillSystemOperationWorker.perform_async(system_operation.id)
        system_operation.update_attribute(:work_id, work_id)
      end

      # Send the second arrear letter for a single arrear
      # @param operation_id [Integer] is the MandrilOperation id, which belong to MandrillSystemOperation will be created
      # @param arrear_id [Integer] used for extract data for sent in the transactional email
      #  @return ...
      def async_send_second_arrear_letter(operation_id, arrear_id)
        operation = MandrillOperation.find(operation_id)
        system_operation = MandrillSystemOperation.create(params: {arrear_id: arrear_id},
                                                          mandrill_operation: operation,
                                                          method_name: 'send_second_arrear_letter_to',
                                                          status: 'initiated')
        work_id = MandrillSystemOperationWorker.perform_async(system_operation.id)
        system_operation.update_attribute(:work_id, work_id)
      end

      # Update all mandrill templates with the Rap styles, this styles are used mainly for display the transactions table
      # @return worker id
      def async_update_templates
        UpdateMandrillTemplatesWorker.perform_async(:arrears)
      end

      # Sent a email to the current user logged with the arrear information related with the selected user
      # @param performer [User] Current user logged
      # @param tenant_id [Integer] User Id selected
      def async_send_test_templates(performer, tenant_id)
        email =  performer.primary_email_value
        SendTestMandrillTemplatesWorker.perform_async(:arrears, email, tenant_id)
      end

      # This is the high level method that send email for each Arrears
      # @param arrears [Array] all Arrears selected by the User
      # @return ...
      def send_arrear_letters(params)
        @arrears ||= filter_arrears(params)
        first_letter_arrears = filter_first_letter_arrears(@arrears)
        second_letter_arrears = filter_second_letter_arrears(@arrears)

        first_letter_arrears.each do |arrear|
          async_send_first_arrear_letter(params[:operation_id], arrear.id)
        end

        second_letter_arrears.each do |arrear|
          async_send_second_arrear_letter(params[:operation_id], arrear.id)
        end
      end

      # Used for the Worker (MandrillSystemOperationWorker) for send the transactional email with first arrear letter
      # @param params [Hash], keys:
      #                           arrear_id [Integer]
      # @return  [Array] API mandrill response, on this case onle have one response
      #        API-Response: [Array] of structs for each recipient containing the key "email" with the email address and "status" as either "sent", "queued", or "rejected"
      #         - [Hash] return[] the sending results for a single recipient
      #             - [String] _id the message's unique id
      #             - [String] email the email address of the recipient
      #             - [String] status the sending status of the recipient - either "sent", "queued", "rejected", or "invalid"
      #             - [String] reject_reason the reason for the rejection if the recipient status is "rejected"
      def send_first_arrear_letter_to(params)
        arrears = @arrears.select{|arrear| arrear.id.eql? params[:arrear_id]}
        recipient = recipients_from_arrear(arrears.first)
        @mailer = SpaceMandrill::Mailer.setup(subject: 'SPACE - Rent Notice (1)',
                                              from_name: default_from_name,
                                              from_email: default_from_email,
                                              template: 'first_arrears_letter_template',
                                              global_merge_vars: default_global_merge_vars)
        @mailer.send_one!(recipient)
      end

      # Used for the Worker (MandrillSystemOperationWorker) for send the transactional email with second arrear letter
      # @param params [Hash], keys:
      #                           arrear_id [Integer]
      # @return  [Array] API mandrill response, on this case onle have one response
      #        API-Response: [Array] of structs for each recipient containing the key "email" with the email address and "status" as either "sent", "queued", or "rejected"
      #         - [Hash] return[] the sending results for a single recipient
      #             - [String] _id the message's unique id
      #             - [String] email the email address of the recipient
      #             - [String] status the sending status of the recipient - either "sent", "queued", "rejected", or "invalid"
      #             - [String] reject_reason the reason for the rejection if the recipient status is "rejected"
      def send_second_arrear_letter_to(params)
        arrears = @arrears.select{|arrear| arrear.id.eql? params[:arrear_id]}
        recipient = recipients_from_arrear(arrears.first)
        @mailer = SpaceMandrill::Mailer.setup(subject: 'SPACE - Rent Notice (2)',
                                              from_name: default_from_name,
                                              from_email: default_from_email,
                                              template: 'second_arrears_letter_template',
                                              global_merge_vars: default_global_merge_vars)
        @mailer.send_one!(recipient)
      end

      # @param params [Hash] with all arrears ids selected by Perfomer (current user)
      # @return [Array] Arrears filtered
      def filter_arrears(params)
        arrears = Arrear.positive_arrears.where(:id => params[:arrear_ids] )
        filter_activated_service_arrears(arrears)
      end
      # @param arrears [Array] set of Arrears
      # @return [Array] Arrears group to which they will send the first letter
      def filter_first_letter_arrears(arrears)
        arrears.select{|arrear|  arrear.have_to_send_first_letter?}
      end

      # @param arrears [Array] set of Arrears
      # @return [Array] Arrears group to which they will send the second letter
      def filter_second_letter_arrears(arrears)
        arrears.reject{|arrear|  arrear.have_to_send_first_letter?}
      end

      # @param arrears [Array]
      # @return [Array] with all Arrears who activated the service for send letters by email
      def filter_activated_service_arrears(arrears)
        deactivated_service_arrears = filter_deactivated_service_arrears(arrears)
        if deactivated_service_arrears.present?
          service_log.warn 'Arrears ids that cannot be sent: because they were deactivated this option'
          service_log.warn ">> #{deactivated_service_arrears}"
        end
        arrears.select{|arrear| arrear.can_emailing?}
      end

      # @param arrears [Array]
      # @return [Array] with all Arrears who deactivated the service for send letters by email
      def filter_deactivated_service_arrears(arrears)
        arrears.reject{|arrear| arrear.can_emailing?}.map(&:id)
      end

      # @param arrears [Array] set of Arrears
      # @return [Array] Recipients group that wrapping a set of Arrears
      def recipients_from_arrears(arrears)
        arrears.map{|arrear| SpaceMandrill::Arrears::Recipient.wrap(arrear)}
      end

      # @return [Hash] with :valid_arrear_ids (those have email) and :invalid_arrear_ids(those do not have email)
      def valid_arrears?(arrear_ids)
        arrears = Arrear.positive_arrears.where(:id => arrear_ids)
        {valid_arrear_ids: valid_arrear_ids(arrears), invalid_arrear_ids: invalid_arrear_ids(arrears)}
      end

      # @param arrears set of arrear Users
      # @return [Array] with all arrear users that haven't email
      def invalid_arrear_ids(arrears)
        arrears.reject{|arrear| has_email?(arrear)}.map(&:id)
      end

      # @param arrears set of arrear Users
      # @return [Array] with all arrear users that have email
      def valid_arrear_ids(arrears)
        arrears.select{|arrear| has_email?(arrear)}.map(&:id)
      end

      # @param arrears [Array] set of Arrears
      # @return [Array] Recipients group that wrapping a set of Arrears
      def recipients_from_arrear(arrear)
        SpaceMandrill::Arrears::Recipient.wrap(arrear)
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

