require 'rails_helper'

RSpec.describe GoogleImageSearchService do
  let(:service) { GoogleImageSearchService.new }
  let(:api_key) { 'test_api_key' }
  let(:search_engine_id) { 'test_search_engine_id' }

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:google, :search_api_key).and_return(api_key)
    allow(Rails.application.credentials).to receive(:dig).with(:google, :search_engine_id).and_return(search_engine_id)
  end

  describe '#initialize' do
    it 'sets API key from credentials' do
      expect(service.instance_variable_get(:@api_key)).to eq(api_key)
      expect(service.instance_variable_get(:@search_engine_id)).to eq(search_engine_id)
    end

    it 'falls back to vision_api_key if search_api_key is nil' do
      allow(Rails.application.credentials).to receive(:dig).with(:google, :search_api_key).and_return(nil)
      allow(Rails.application.credentials).to receive(:dig).with(:google, :vision_api_key).and_return('vision_key')
      
      new_service = GoogleImageSearchService.new
      expect(new_service.instance_variable_get(:@api_key)).to eq('vision_key')
    end

    it 'falls back to ENV variables if credentials are nil' do
      allow(Rails.application.credentials).to receive(:dig).and_return(nil)
      allow(ENV).to receive(:[]).with('GOOGLE_SEARCH_API_KEY').and_return('env_key')
      allow(ENV).to receive(:[]).with('GOOGLE_SEARCH_ENGINE_ID').and_return('env_engine')
      
      new_service = GoogleImageSearchService.new
      expect(new_service.instance_variable_get(:@api_key)).to eq('env_key')
      expect(new_service.instance_variable_get(:@search_engine_id)).to eq('env_engine')
    end
  end

  describe '#search_product_image' do
    let(:mock_response) do
      {
        'items' => [
          {
            'link' => 'https://example.com/image1.jpg',
            'title' => 'Product Photo iPhone 13',
            'snippet' => 'Official product image',
            'image' => { 'width' => 500, 'height' => 500 }
          },
          {
            'link' => 'https://amazon.com/image2.jpg',
            'title' => 'iPhone 13 Product',
            'snippet' => 'Amazon product listing',
            'image' => { 'width' => 600, 'height' => 600 }
          }
        ]
      }
    end

    before do
      stub_request(:get, /www.googleapis.com\/customsearch\/v1/)
        .to_return(status: 200, body: mock_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end

  end

  describe '#search_merchant_logo' do
    let(:mock_logo_response) do
      {
        'items' => [
          {
            'link' => 'https://example.com/logo.png',
            'title' => 'Apple Logo',
            'snippet' => 'Official Apple logo',
            'image' => { 'width' => 200, 'height' => 200 }
          }
        ]
      }
    end

    before do
      stub_request(:get, /www.googleapis.com\/customsearch\/v1/)
        .to_return(status: 200, body: mock_logo_response.to_json, headers: { 'Content-Type' => 'application/json' })
    end
  end

  describe 'private methods' do
    describe '#build_image_query' do
      it 'builds query with product name only' do
        query = service.send(:build_image_query, 'iPhone 13', nil)
        expect(query).to eq('iPhone 13 product image')
      end

      it 'builds query with product name and merchant' do
        query = service.send(:build_image_query, 'iPhone 13', 'Apple')
        expect(query).to eq('iPhone 13 Apple product image')
      end
    end

    describe '#find_best_image' do
      let(:items) do
        [
          {
            'link' => 'https://example.com/logo.png',
            'title' => 'Company Logo',
            'snippet' => 'Official logo image',
            'image' => { 'width' => 200, 'height' => 200 }
          },
          {
            'link' => 'https://amazon.com/product.jpg',
            'title' => 'Product Photo',
            'snippet' => 'High quality product image',
            'image' => { 'width' => 500, 'height' => 500 }
          },
          {
            'link' => 'https://example.com/other.jpg',
            'title' => 'Other Image',
            'snippet' => 'Random image',
            'image' => { 'width' => 100, 'height' => 100 }
          }
        ]
      end

      it 'prefers product photos over logos' do
        result = service.send(:find_best_image, items, 'test query')
        expect(result['title']).to include('Product Photo')
      end

      it 'prefers images from preferred domains' do
        result = service.send(:find_best_image, items, 'test query')
        expect(result['link']).to include('amazon.com')
      end

      it 'prefers larger images' do
        result = service.send(:find_best_image, items, 'test query')
        expect(result['image']['width']).to be >= 300
      end

      it 'returns first image if all scores are low' do
        low_score_items = [
          {
            'link' => 'https://example.com/icon.png',
            'title' => 'Icon Badge',
            'snippet' => 'Small icon',
            'image' => { 'width' => 50, 'height' => 50 }
          }
        ]
        
        result = service.send(:find_best_image, low_score_items, 'test query')
        expect(result).to eq(low_score_items.first)
      end
    end

    describe '#find_best_logo' do
      let(:logo_items) do
        [
          {
            'link' => 'https://example.com/product.jpg',
            'title' => 'Product Image',
            'snippet' => 'Product photo',
            'image' => { 'width' => 500, 'height' => 300 }
          },
          {
            'link' => 'https://apple.com/logo.png',
            'title' => 'Apple Logo',
            'snippet' => 'Official company logo',
            'image' => { 'width' => 200, 'height' => 200 }
          }
        ]
      end

      it 'prefers images with "logo" in title' do
        result = service.send(:find_best_logo, logo_items, 'test query')
        expect(result['title']).to include('Logo')
      end

      it 'prefers images from official domains' do
        result = service.send(:find_best_logo, logo_items, 'test query')
        expect(result['link']).to include('apple.com')
      end

      it 'prefers square-ish images for logos' do
        result = service.send(:find_best_logo, logo_items, 'test query')
        width = result['image']['width']
        height = result['image']['height']
        aspect_ratio = width.to_f / height
        expect(aspect_ratio).to be_between(0.8, 1.2)
      end

      it 'avoids product photos when looking for logos' do
        result = service.send(:find_best_logo, logo_items, 'test query')
        expect(result['title']).not_to include('Product Image')
      end
    end

    describe '#valid_image_url?' do
      it 'returns true for valid HTTP URLs' do
        expect(service.send(:valid_image_url?, 'http://example.com/image.jpg')).to be true
      end

      it 'returns true for valid HTTPS URLs' do
        expect(service.send(:valid_image_url?, 'https://example.com/image.jpg')).to be true
      end

      it 'returns false for blank URLs' do
        expect(service.send(:valid_image_url?, '')).to be false
        expect(service.send(:valid_image_url?, nil)).to be false
      end

      it 'returns false for invalid URLs' do
        expect(service.send(:valid_image_url?, 'not-a-url')).to be false
        expect(service.send(:valid_image_url?, 'ftp://example.com/file')).to be false
      end

      it 'handles URI parse errors' do
        expect(service.send(:valid_image_url?, 'http://[invalid')).to be false
      end
    end
  end
end