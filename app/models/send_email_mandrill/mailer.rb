require 'mandrill'
module SendEmailMandrill
  class Mailer

    include ActiveAttr::AttributeDefaults
    include ActiveAttr::MassAssignment

    # Mandrill api key
    attribute :api_key, default: APP_CONFIG[:mandrill_api_key]
    # Template to use
    attribute :template
    #
    attribute :subject
    # The name to appear when the email is sent
    attribute :from_name
    # The email to appear when the email is sent
    attribute :from_email
    # If you are not using a template, but a specific plain text, use this
    attribute :text
    # If you are not using a template, but a specific html content, use this
    attribute :html
    # Wheter or not to use the merge vars from the recipients in the email
    attribute :use_merge_vars, default: true
    # Wheter
    attribute :global_merge_vars, default: []
    # Use this when sending to multiple
    attribute :custom_html_data
    # API response
    attribute :responses, default: []

    # custom config the mandrill wrapper and API
    # @param config [Hash] with the info for customize the mailer setup
    # @return [Mandrill::Mailer] this class with a new config
    def self.setup(config = {})
      mailer = new(config)
      mailer.instance_eval do
        @mandrill = Mandrill::API.new(api_key)
      end
      mailer
    end

    # High level method for send email one by one  or all in batch
    # @param recipients [Array][Recipient] they were configured by some class that inherits of GenericRecipient class
    # @return ***
    def send!(recipients)
      sending_method = autodetect_sending_method(recipients)
      self.__send__(sending_method, recipients)
    end

    # Detect if the recipients contain the custom html data, in the case is true send the emails one by one because this content is unique for each Recipient
    # in other case send all emails in one request
    # @param recipients [Arrear]
    # @return [Symbol] this is the correct method for send the Recipients group
    def autodetect_sending_method(recipients)
      recipients.first.custom_html_data.present? ? :send_one_by_one! : :send_to_multiple!
    end

    # Send all recipients in one request to the API
    # @param recipients [Array]
    # @return [Array] of structs for each recipient containing the key "email" with the email address and "status" as either "sent", "queued", or "rejected"
    #     - [Hash] return[] the sending results for a single recipient
    #             - [String] _id the message's unique id
    #             - [String] email the email address of the recipient
    #             - [String] status the sending status of the recipient - either "sent", "queued", "rejected", or "invalid"
    #             - [String] reject_reason the reason for the rejection if the recipient status is "rejected"
    def send_to_multiple!(recipients)
      message_data = message_data(recipients)
      responses << @mandrill.messages.send_template(template_name, custom_html_data, message_data)
    end

    # Send the emails one by one for each recipient (multiple request to the API)
    # @param recipients [Array]
    # @return [Array] of structs for each recipient containing the key "email" with the email address and "status" as either "sent", "queued", or "rejected"
    #     - [Hash] return[] the sending results for a single recipient
    #             - [String] _id the message's unique id
    #             - [String] email the email address of the recipient
    #             - [String] status the sending status of the recipient - either "sent", "queued", "rejected", or "invalid"
    #             - [String] reject_reason the reason for the rejection if the recipient status is "rejected"
    def send_one_by_one!(recipients)
      recipients.each do |recipient|
        message_data = message_data([recipient])
        responses << @mandrill.messages.send_template(template, recipient.custom_html_data, message_data)
      end
      responses
    end

    # Send one transactional email with the recipient data
    # allow save easily the response information in the Sidekiq Worker
    # @param recipient [String]
    # @return [Array] of structs for each recipient containing the key "email" with the email address and "status" as either "sent", "queued", or "rejected"
    #     - [Hash] return[] the sending results for a single recipient
    #             - [String] _id the message's unique id
    #             - [String] email the email address of the recipient
    #             - [String] status the sending status of the recipient - either "sent", "queued", "rejected", or "invalid"
    #             - [String] reject_reason the reason for the rejection if the recipient status is "rejected"
    def send_one!(recipient)
      message_data = message_data([recipient])
      @mandrill.messages.send_template(template, recipient.custom_html_data, message_data)
    end

    # Build a final message with all configured variable  that will be sent
    # @param recipients [Array]
    # @return [Hash] the message as it is supposed to be sent directly to the Mandrill API
    def message_data(recipients)
      {
          subject: subject,
          from_name: from_name,
          text: text,
          html: html,
          from_email: from_email,
          merge: use_merge_vars,
      }.merge(recipient_data(recipients)).delete_if{|key, value| value.blank?}.merge(global_merge_vars: global_merge_vars)
    end

    private
    # @param recipients [Array]
    # @return [Hash] with the to and merge vars Arrays configured with Recipients info
    def recipient_data(recipients)
      {
          to: recipients.map(&:to),
          merge_vars: recipients.map(&:merge_vars),
      }
    end
  end
end