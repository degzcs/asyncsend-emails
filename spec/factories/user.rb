# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do

  factory :user do

    name {"Test User #{User.count + 1}"}
    email {"email_#{User.count + 1}@example.com"}
    password {(1..Devise.password_length.min).to_a.join}
    password_confirmation { |u| u.password }

  end
end
