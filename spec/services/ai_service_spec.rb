
require "rails_helper"

RSpec.describe AiService, type: :service do
  def gemini_response(json_text)
    {
      "candidates" => [
        { "content" => { "parts" => [ { "text" => json_text } ] } }
      ]
    }
  end


  class FakeGeminiClient
    def initialize(resp_map = {})
      @resp_map = resp_map 
    end

    def generate_content(args)
      handler = @resp_map[:generate_content]
      return handler.call(args) if handler.respond_to?(:call)
      handler || {}
    end
  end

  let(:receipt_json) do
    <<~JSON
    ```json
    {
      "is_receipt": true,
      "product_name": "Widget Pro",
      "merchant": "Amazon",
      "purchase_date": "2025-01-02",
      "warranty_length_months": 12,
      "warranty_type": "manufacturer",
      "return_policy_days": 30,
      "return_deadline": "2025-02-01"
    }
    ```
    JSON
  end

  let(:non_receipt_json) { %({"is_receipt": false}) }
  let(:bad_json)         { "{not json" }

  context "with injected client (DI)" do
    let(:client) do
      FakeGeminiClient.new(
        generate_content: ->(_args) { gemini_response(receipt_json) }
      )
    end
    subject(:service) { described_class.new(client: client) }

    it "parses receipt JSON and strips ```json fences" do
      result = service.extract_receipt_info("Your order shipped!")
      expect(result).to eq({
        "is_receipt"=>true,
        "product_name"=>"Widget Pro",
        "merchant"=>"Amazon",
        "purchase_date"=>"2025-01-02",
        "warranty_length_months"=>12,
        "warranty_type"=>"manufacturer",
        "return_policy_days"=>30,
        "return_deadline"=>"2025-02-01"
      })
    end

    it "returns nil when AI says not a receipt" do
      client2 = FakeGeminiClient.new(generate_content: gemini_response(non_receipt_json))
      svc = described_class.new(client: client2)
      expect(svc.extract_receipt_info("Newsletter")).to be_nil
    end

    it "returns nil on JSON parse error and logs" do
      client3 = FakeGeminiClient.new(generate_content: gemini_response(bad_json))
      svc = described_class.new(client: client3)
      expect(svc.extract_receipt_info("content")).to be_nil
    end

    it "lookup_warranty_info parses JSON" do
      client4 = FakeGeminiClient.new(generate_content: gemini_response(%({"standard_warranty_months":12,"warranty_terms":"1y","exclusions":"wear","return_policy_days":30})))
      svc = described_class.new(client: client4)
      result = svc.lookup_warranty_info("Widget", "Amazon")
      expect(result).to include("standard_warranty_months"=>12, "return_policy_days"=>30)
    end

    it "check_warranty_eligibility parses JSON" do
      client5 = FakeGeminiClient.new(generate_content: gemini_response(%({"is_covered":true,"reasoning":"OK","recommended_action":"Contact support"})))
      svc = described_class.new(client: client5)
      result = svc.check_warranty_eligibility("Widget", "Screen cracked", "Standard terms")
      expect(result).to include("is_covered"=>true, "recommended_action"=>"Contact support")
    end
  end

 
  context "without DI (class as-is)" do
    it "sets @client=nil when gem missing (LoadError) and methods return nil" do
      allow(Kernel).to receive(:require).with("gemini-ai").and_raise(LoadError.new("no gem"))
      svc = described_class.new
      expect(svc.extract_receipt_info("anything")).to be_nil
      expect(svc.lookup_warranty_info("Widget")).to be_nil
      expect(svc.check_warranty_eligibility("Widget","Issue","Terms")).to be_nil
    end

    it "uses a real Gemini.new stub when gem present" do
      # pretend 'require' succeeds
      allow(Kernel).to receive(:require).with("gemini-ai").and_return(true)
      fake = FakeGeminiClient.new(generate_content: gemini_response(%({"is_receipt": false})))
      stub_const("Gemini", Class.new) unless defined?(Gemini)
      allow(Gemini).to receive(:new).and_return(fake)

      svc = described_class.new
      expect(svc.extract_receipt_info("content")).to be_nil  # is_receipt false
    end
  end

  it "rescues runtime errors from client and returns nil" do
    bad_client = FakeGeminiClient.new(generate_content: ->(_args) { raise "boom" })
    svc = described_class.new(client: bad_client)
    expect(svc.extract_receipt_info("x")).to be_nil
    expect(svc.lookup_warranty_info("Widget")).to be_nil
    expect(svc.check_warranty_eligibility("W","I","T")).to be_nil
  end
end
