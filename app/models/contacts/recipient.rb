module Contacts
# subclass to define the @ attributes your template will use
  class Recipient < GenericRecipient

    # VARS mapping, keys: are the API params (or parmeters) names and
    #               values: are the methods belongs to Contact Model
    # IMPORTANT!!! all methods for call should be located in the Model Class (or delegated method).
    attribute :vars_mapping , default: {
        NAME: :name,
        ADDRESS: :address
    }

    # this method allow use the Arrears Model for send its methods
    # @return [Contact]
    def contacts
      wrapped_object
    end

    # Overrides custom_html_data from GenericRecipient
    # In this case, it's not implemented, due we do not need rendering any partial or view
    def custom_html_data
    end

  end
end

