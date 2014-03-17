require 'spec_helper'

describe User do

  context 'factory should work' do
    subject { build(:user) }
    its(:name) { should be_present }
    its(:email) { should be_present }
    #
  end

end

