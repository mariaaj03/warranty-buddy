# spec/services/ai_service_spec.rb
require 'rails_helper'
RSpec.describe AiService, type: :service do
  it "initializes" do
    expect { described_class.new }.not_to raise_error
  end
end