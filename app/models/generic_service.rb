module SpaceMandrill

  class GenericService

    # Template types that can be send by email through the Mandrill service
    TEMPLATE_TYPES = [:arrears_letters, :electricity_invoices, :rent_statments]

    include ActiveAttr::AttributeDefaults

    attribute :global_merge_vars_mapping , default: {
        COMPANY_ADDRESS: :company_address,
        COMPANY_EMAIL: :company_email,
        COMPANY_WWW: :company_www,
        COMPANY_PHONE: :company_phone,
        COMPANY_FAX: :company_fax,
        COMPANY_INFO: :company_info,
    }

    class << self

      def global_merge_vars
        @globlal_merge_vars ||= global_merge_vars_mapping.map{|var_name, method_name| {name: var_name, content: @settings.try(method_name).to_s}}
      end

      def global_merge_vars_mapping
        GenericService.new.global_merge_vars_mapping
      end


      def default_from_name
        'SPACE'
      end

      def default_from_email
        'fiona@spacestudios.org.uk'
      end

      def default_global_merge_vars
        @settings ||= SpaceSettings.first
        global_merge_vars
      end

      # verify if this user has an email
      # @param user [User]
      # @return [Boolean] true if user has a email and viceversa
      def has_email?(user)
        user.primary_email_value.present?
      end

      # @retun [SpaceMandrill::Logger] with the methods of Rails Logger
      def service_log
        log_file = File.open("#{Rails.root}/log/mandrill.log", 'a')
        log_file.sync = true
        SpaceMandrill::Logger.new(log_file)
      end
    end

  end

end
