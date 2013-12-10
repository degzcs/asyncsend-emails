class MandrillOperation
  include Mongoid::Document
  field :params, :type => Hash
  belongs_to :performer, class_name: 'User'
  has_many :mandrill_system_operations
end
