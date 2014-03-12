# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
#require 'rspec/autorun'
require 'capybara/rspec'
require 'database_cleaner'
require 'active_attr/rspec'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Configure Capybara
Capybara.default_host = "http://127.0.0.1"
Capybara.javascript_driver = :webkit

#include seeds
#require "#{Rails.root}/db/test_seeds.rb"

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  #config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  #config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  # DatabaseCleaner config

  static_info_tables = %w[]

  config.before(:suite) do
    #if example.metadata[:js]
    #  DatabaseCleaner.strategy = :truncation, {except: static_info_tables}
    #else
    DatabaseCleaner.strategy = :truncation, {except: static_info_tables}
    #end
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  # Factory Girl methods
  config.include FactoryGirl::Syntax::Methods

  # Include devise test helpers in controller specs
  config.include Devise::TestHelpers, :type => :controller

  # Include mongoid matches in model specs
  config.include Mongoid::Matchers, type: :model

  config.treat_symbols_as_metadata_keys_with_true_values = true

  config.include Capybara::DSL

end
