# spec/services/ai_service_spec.rb
require "rails_helper"

RSpec.describe AiService do
  before do
    # Default: no creds in Rails credentials; ENV set per example
    allow(Rails.application).to receive(:credentials).and_return(double(dig: nil))
  end

  describe "initialize" do
    it "uses provided client and ignores API key" do
      s = described_class.new(:fake_client)
      expect(s.instance_variable_get(:@client)).to eq(:fake_client)
      expect(s.instance_variable_get(:@api_key)).to be_nil
    end

    it "enables REST mode when GOOGLE_GEMINI_API_KEY present" do
      allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return("KEY")
      s = described_class.new
      expect(s.instance_variable_get(:@client)).to eq(:rest_api)
      expect(s.instance_variable_get(:@api_key)).to eq("KEY")
    end

    it "sets client nil when no API key" do
      allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
      s = described_class.new
      expect(s.instance_variable_get(:@client)).to be_nil
    end
  end

  context "with API client enabled" do
    let(:service) do
      allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return("KEY")
      described_class.new
    end

    describe "#extract_receipt_info" do
      it "returns parsed hash when AI says is_receipt=true" do
        json = %({"is_receipt":true,"product_name":"Echo","merchant":"Amazon","purchase_date":"2024-01-01"})
        allow(service).to receive(:call_gemini_api).and_return(json)
        out = service.extract_receipt_info("email text")
        expect(out).to be_a(Hash)
        expect(out["product_name"]).to eq("Echo")
      end

      it "strips ```json fences" do
        json = "```json\n{\"is_receipt\":true,\"product_name\":\"Phone\",\"merchant\":\"Apple\",\"purchase_date\":\"2024-05-01\"}\n```"
        allow(service).to receive(:call_gemini_api).and_return(json)
        expect(service.extract_receipt_info("x")["product_name"]).to eq("Phone")
      end

      it "strips ```json with leading whitespace" do
        json = "```json   \n{\"is_receipt\":true,\"product_name\":\"Phone\"}\n```"
        allow(service).to receive(:call_gemini_api).and_return(json)
        expect(service.extract_receipt_info("x")["product_name"]).to eq("Phone")
      end

      it "strips trailing ``` with whitespace" do
        json = "{\"is_receipt\":true,\"product_name\":\"Phone\"}\n```   "
        allow(service).to receive(:call_gemini_api).and_return(json)
        expect(service.extract_receipt_info("x")["product_name"]).to eq("Phone")
      end

      it "handles JSON without markdown fences" do
        json = "{\"is_receipt\":true,\"product_name\":\"Phone\",\"merchant\":\"Apple\",\"purchase_date\":\"2024-05-01\"}"
        allow(service).to receive(:call_gemini_api).and_return(json)
        expect(service.extract_receipt_info("x")["product_name"]).to eq("Phone")
      end

      it "returns nil when AI says not a receipt" do
        allow(service).to receive(:call_gemini_api).and_return(%({"is_receipt":false}))
        expect(service.extract_receipt_info("x")).to be_nil
      end

      it "rescues and returns nil on bad JSON" do
        allow(service).to receive(:call_gemini_api).and_return("not-json")
        expect(service.extract_receipt_info("x")).to be_nil
      end
    end

    describe "#lookup_warranty_info" do
      it "parses JSON and returns hash" do
        allow(service).to receive(:call_gemini_api).and_return(%({"standard_warranty_months":12}))
        out = service.lookup_warranty_info("Phone", "Apple")
        expect(out["standard_warranty_months"]).to eq(12)
      end

      it "strips markdown code blocks from lookup response" do
        json = "```json\n{\"standard_warranty_months\":12}\n```"
        allow(service).to receive(:call_gemini_api).and_return(json)
        out = service.lookup_warranty_info("Phone", "Apple")
        expect(out["standard_warranty_months"]).to eq(12)
      end

      it "rescues on JSON error and returns nil" do
        allow(service).to receive(:call_gemini_api).and_return("bad")
        expect(service.lookup_warranty_info("x")).to be_nil
      end
    end

    describe "#check_warranty_eligibility" do
      it "parses JSON result" do
        allow(service).to receive(:call_gemini_api).and_return(%({"is_covered":true,"reasoning":"ok"}))
        out = service.check_warranty_eligibility("Phone", "screen cracked", "1yr")
        expect(out["is_covered"]).to eq(true)
      end

      it "strips markdown code blocks from eligibility response" do
        json = "```json\n{\"is_covered\":true,\"reasoning\":\"ok\"}\n```"
        allow(service).to receive(:call_gemini_api).and_return(json)
        out = service.check_warranty_eligibility("Phone", "screen cracked", "1yr")
        expect(out["is_covered"]).to eq(true)
      end

      it "rescues on error and returns nil" do
        allow(service).to receive(:call_gemini_api).and_return("bad")
        expect(service.check_warranty_eligibility("x","y","z")).to be_nil
      end
    end

    describe "#extract_receipt_info_from_image" do
      it "returns parsed result when AI says is_receipt=true" do
        allow(service).to receive(:call_gemini_api_with_image)
          .and_return(%({"is_receipt":true,"product_name":"Mug","merchant":"Target","purchase_date":"2024-02-02"}))
        out = service.extract_receipt_info_from_image("BASE64")
        expect(out["product_name"]).to eq("Mug")
      end

      it "strips markdown code blocks from image response" do
        json = "```json\n{\"is_receipt\":true,\"product_name\":\"Mug\",\"merchant\":\"Target\",\"purchase_date\":\"2024-02-02\"}\n```"
        allow(service).to receive(:call_gemini_api_with_image).and_return(json)
        out = service.extract_receipt_info_from_image("BASE64")
        expect(out["product_name"]).to eq("Mug")
      end

      it "returns nil when AI says not a receipt" do
        allow(service).to receive(:call_gemini_api_with_image).and_return(%({"is_receipt":false}))
        expect(service.extract_receipt_info_from_image("b64")).to be_nil
      end

      it "rescues and returns nil on bad JSON" do
        allow(service).to receive(:call_gemini_api_with_image).and_return("oops")
        expect(service.extract_receipt_info_from_image("b64")).to be_nil
      end
    end

    describe "#answer_warranty_question" do
      it "returns text answer trimmed" do
        allow(service).to receive(:call_gemini_api).and_return(" hello ")
        out = service.answer_warranty_question("What is coverage?")
        expect(out).to eq("hello")
      end

      it "returns fallback message when response_text is nil" do
        allow(service).to receive(:call_gemini_api).and_return(nil)
        out = service.answer_warranty_question("What is coverage?")
        expect(out).to eq("I'm sorry, I couldn't generate a response. Please try rephrasing your question.")
      end

      it "returns fallback message when response_text is empty" do
        allow(service).to receive(:call_gemini_api).and_return("")
        out = service.answer_warranty_question("What is coverage?")
        expect(out).to eq("I'm sorry, I couldn't generate a response. Please try rephrasing your question.")
      end

      it "raises if underlying call_gemini_api raises" do
        allow(service).to receive(:call_gemini_api).and_raise(StandardError.new("fail"))
        expect { service.answer_warranty_question("Q") }.to raise_error(StandardError)
      end

      it "adds search context when provided" do
        results = [
          { title: "Doc1", snippet: "S1", url: "u1" },
          { title: "Doc2", snippet: "S2", url: "u2" }
        ]
        expect(service).to receive(:call_gemini_api) do |prompt|
          expect(prompt).to include("Relevant information from web search")
          expect(prompt).to include("Doc1")
          expect(prompt).to include("u2")
          "ok"
        end
        service.answer_warranty_question("Q", results)
      end

      it "does not add search context when search_results is nil" do
        expect(service).to receive(:call_gemini_api) do |prompt|
          expect(prompt).not_to include("Relevant information from web search")
          "ok"
        end
        service.answer_warranty_question("Q", nil)
      end

      it "does not add search context when search_results is empty" do
        expect(service).to receive(:call_gemini_api) do |prompt|
          expect(prompt).not_to include("Relevant information from web search")
          "ok"
        end
        service.answer_warranty_question("Q", [])
      end

      it "limits search results to first 5 items" do
        results = (1..7).map { |i| { title: "Doc#{i}", snippet: "S#{i}", url: "u#{i}" } }
        expect(service).to receive(:call_gemini_api) do |prompt|
          expect(prompt).to include("Doc1")
          expect(prompt).to include("Doc5")
          expect(prompt).not_to include("Doc6")
          expect(prompt).not_to include("Doc7")
          "ok"
        end
        service.answer_warranty_question("Q", results)
      end
    end

    describe "rate limit / errors (call_gemini_api)" do
      it "retries once on 429 with small retryDelay then raises GeminiRateLimitError" do
        body429 = {
          error: {
            message: "Rate limit",
            details: [{ "@type" => "type.googleapis.com/google.rpc.RetryInfo", "retryDelay" => "1s" }]
          }
        }.to_json

        # Build a fake HTTP flow by stubbing Net::HTTP
        response_429 = instance_double("Net::HTTPTooManyRequests", code: "429", body: body429)
        response_429_2 = instance_double("Net::HTTPTooManyRequests", code: "429", body: body429)
        response_200 = instance_double("Net::HTTPOK", code: "200", body: %({"candidates":[{"content":{"parts":[{"text":"ok"}]}}]}))

        # Force: first 429 (retry), second 429 (raise)
        http = instance_double("Net::HTTP")
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:request).and_return(response_429, response_429_2)

        # Avoid sleeping during tests
        allow_any_instance_of(AiService).to receive(:sleep)

        expect {
          service.send(:call_gemini_api, "prompt")
        }.to raise_error(GeminiRateLimitError)
      end

      it "raises generic API error for non-200/429" do
        body500 = { error: { message: "Internal" } }.to_json
        http = instance_double("Net::HTTP")
        resp = instance_double("Net::HTTPInternalServerError", code: "500", body: body500)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:request).and_return(resp)
        expect { service.send(:call_gemini_api, "x") }.to raise_error(RuntimeError, /Gemini API error: 500/i)
      end

      it "raises on invalid JSON with parse error text" do
        http = instance_double("Net::HTTP")
        resp = instance_double("Net::HTTPOK", code: "200", body: "not-json")
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:request).and_return(resp)
        expect { service.send(:call_gemini_api, "x") }.to raise_error(RuntimeError, /Invalid response format/)
      end
    end

    describe "call_gemini_api_with_image basic error" do
      it "raises on 500 error" do
        http = instance_double("Net::HTTP")
        resp = instance_double("Net::HTTPInternalServerError", code: "500", body: { error: { message: "bad" } }.to_json)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:request).and_return(resp)
        expect { service.send(:call_gemini_api_with_image, "p", "b64") }.to raise_error(RuntimeError, /Gemini API error: 500/i)
      end
    end

  end

  context "with no client (no API key)" do
    let(:service) do
      allow(ENV).to receive(:[]).with("GOOGLE_GEMINI_API_KEY").and_return(nil)
      described_class.new
    end

    it "returns nil early for extract_receipt_info / lookup / eligibility / image / answer" do
      expect(service.extract_receipt_info("x")).to be_nil
      expect(service.lookup_warranty_info("p","m")).to be_nil
      expect(service.check_warranty_eligibility("p","i","t")).to be_nil
      expect(service.extract_receipt_info_from_image("b64")).to be_nil

      # answer_warranty_question returns string or raises? It returns nil unless @client; here @client=nil so:
      expect(service.answer_warranty_question("Q")).to be_nil
    end
  end
end
