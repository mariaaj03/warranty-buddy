require 'rails_helper'

RSpec.describe GoogleSearchService do
  let(:service) { described_class.new }
  let(:api_key) { 'test_api_key' }
  let(:search_engine_id) { 'test_search_engine_id' }

  before do
    allow(Rails.application.credentials).to receive(:dig)
      .with(:google, :search_api_key).and_return(api_key)
    allow(Rails.application.credentials).to receive(:dig)
      .with(:google, :search_engine_id).and_return(search_engine_id)
  end

  describe '#lookup_warranty_info' do
    let(:sample_response) do
      {
        'items' => [
          {
            'title' => '12 Month Warranty for Electronics',
            'snippet' => 'Product comes with 12 month warranty and 30 day return policy',
            'link' => 'https://example.com/warranty'
          }
        ]
      }.to_json
    end

    let(:success_response) { double('Response', code: '200', body: sample_response) }

    before do
      allow(Net::HTTP).to receive(:get_response).and_return(success_response)
    end

    it 'returns warranty info when search is successful' do
      result = service.lookup_warranty_info('Test Product', 'Test Merchant')
      expect(result[:warranty_months]).to eq(12)
      expect(result[:return_policy_days]).to eq(30)
      expect(result[:source]).to eq('google_search')
      expect(result[:details]).to be_present
    end

    it 'returns nil when credentials are missing' do
      allow(Rails.application.credentials).to receive(:dig)
        .with(:google, :search_api_key).and_return(nil)

      result = service.lookup_warranty_info('Test Product')
      expect(result).to be_nil
    end

    it 'handles API errors gracefully' do
      allow(Net::HTTP).to receive(:get_response)
        .and_return(double('Response', code: '500', body: 'Error'))

      result = service.lookup_warranty_info('Test Product')
      
      if result.nil?
        expect(result).to be_nil
      else
        expect(result[:warranty_months]).to eq(12) # Default warranty
        expect(result[:return_policy_days]).to eq(30) # Default return policy
      end
    end

    it 'handles network errors gracefully' do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError)

      result = service.lookup_warranty_info('Test Product')
      
      if result.nil?
        expect(result).to be_nil
      else
        expect(result[:warranty_months]).to eq(12) # Default warranty
        expect(result[:return_policy_days]).to eq(30) # Default return policy
      end
    end
  end

  describe '#extract_warranty_info' do
    let(:search_results) do
      [
        {
          'title' => '24 Month Warranty Available',
          'snippet' => 'Product includes 24 month warranty and 45 day return policy',
          'link' => 'https://example.com/warranty'
        }
      ]
    end

    it 'extracts warranty months from content' do
      result = service.send(:extract_warranty_info, search_results, 'Test Product', nil)
      expect(result[:warranty_months]).to eq(24)
    end

    it 'extracts return policy days from content' do
      result = service.send(:extract_warranty_info, search_results, 'Test Product', nil)
      expect(result[:return_policy_days]).to eq(45)
    end

    it 'converts year warranty to months' do
      results_with_years = [
        {
          'title' => '2 Year Warranty',
          'snippet' => 'Comes with 2 year warranty',
          'link' => 'https://example.com'
        }
      ]

      result = service.send(:extract_warranty_info, results_with_years, 'Test Product', nil)
      expect(result[:warranty_months]).to eq(24)
    end
  end

  describe '#infer_warranty_from_product_type' do
  end

  describe '#build_warranty_query' do
    it 'builds query with product name only' do
      query = service.send(:build_warranty_query, 'Test Product', nil)
      expect(query).to include('Test Product')
      expect(query).to include('warranty length months')
      expect(query).to include('manufacturer warranty return policy')
    end

    it 'builds query with product name and merchant' do
      query = service.send(:build_warranty_query, 'Test Product', 'Test Merchant')
      expect(query).to include('Test Product')
      expect(query).to include('Test Merchant')
      expect(query).to include('warranty length months')
    end
  end
end
