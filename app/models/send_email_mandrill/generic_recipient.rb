module SendEmailMandrill
  class GenericRecipient

    include ActiveAttr::AttributeDefaults

    # this the object that will be wrapped
    attribute :wrapped_object

    # @param wrapped_object [Model] can be Contacts, ....
    # @return [Recipient] config with wrapped object and his parameters with the wrapped object data
    def self.wrap(wrapped_object)
      recipient = self.new
      recipient.wrapped_object =  wrapped_object
      recipient.precompile!
      recipient
    end

    # These methods can be overriden if the wrapped object does not comply with the required interface

    # @return [Hash] that containt recipient email and name
    def to
      @to ||= {email: wrapped_object.primary_email_value, name: wrapped_object.name}
    end

    # @return [Array] that containt the vars configured with the recipient info
    def vars
      @vars ||= vars_mapping.map do|var_name, method_name|
        if method_name.is_a? Symbol
          {name: var_name, content: wrapped_object.try(method_name).to_s}
        else
          {name: var_name, content: self.try(method_name).to_s}
        end
      end
    end

    # @param var_name [Symbol] should be like appears in recipient vars
    # @return [String] whit var value
    def var_value(var_name)
      vars.map{|var| var[:content] if var[:name].eql? var_name }.flatten.compact.first
    end

    # @return [Hash] that containt recipient rcpt(email) and vars[Array] configured
    def merge_vars
      @merge_vars ||= {rcpt: wrapped_object.primary_email_value, vars: vars}
    end

    # @return [Array] with the rendered template content as needed by the API
    def custom_html_data
      raise "Implement this based on the needs of your system"
    end

    # Reduces memory footprint doing the precompilation of the useful information hash required
    # @return [Recipient]
    def precompile!
      # force the loading of the merge_vars, to and custom_html_data
      to
      merge_vars
      custom_html_data
      # free memory by setting the wrapped object to nil
      self.wrapped_object = nil
      self
    end

  end
end