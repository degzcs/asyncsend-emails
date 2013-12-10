class MandrillSystemOperation
  include Mongoid::Document
  field :params,:type => Hash
  belongs_to :mandrill_operation

end
