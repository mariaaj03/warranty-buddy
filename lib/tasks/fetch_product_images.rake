namespace :products do
  desc "Fetch images for products that don't have images"
  task fetch_images: :environment do
    products_without_images = Product.where(image_url: [nil, ""])
    
    puts "Found #{products_without_images.count} products without images"
    
    image_service = GoogleImageSearchService.new
    
    # Check if API is configured
    unless image_service.instance_variable_get(:@api_key) && image_service.instance_variable_get(:@search_engine_id)
      puts "⚠️  ERROR: Google Custom Search API not configured!"
      puts "   Please add search_api_key and search_engine_id to Rails credentials"
      puts "   Run: EDITOR='nano' rails credentials:edit"
      exit 1
    end
    
    products_without_images.find_each do |product|
      puts "Fetching image for: #{product.product_name} (#{product.merchant})"
      
      begin
        # Try product image first
        image_url = image_service.search_product_image(product.product_name, product.merchant)
        
        # If no product image, try merchant logo as fallback
        if image_url.blank? && product.merchant.present?
          puts "  🔄 Product image not found, trying merchant logo..."
          image_url = image_service.search_merchant_logo(product.merchant)
        end
        
        if image_url.present?
          product.update_column(:image_url, image_url)
          image_type = image_url.include?("logo") ? "merchant logo" : "product image"
          puts "  ✅ Found #{image_type}: #{image_url}"
        else
          puts "  ⚠️  No image found"
        end
      rescue => e
        puts "  ❌ Error: #{e.message}"
      end
      
      # Small delay to avoid rate limiting
      sleep 0.5
    end
    
    puts "\n✅ Done!"
  end
end

