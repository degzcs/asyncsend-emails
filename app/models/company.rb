class Company
  include Mongoid::Document
  field :address, type: String
  field :web_site, type: String
  field :email, type: String
  field :phone, type: String
  field :fax, type: String
  field :info, type: String
end