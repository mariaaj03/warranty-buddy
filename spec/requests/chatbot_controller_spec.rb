require 'rails_helper'

RSpec.describe ChatbotController, type: :request do
  include Devise::Test::IntegrationHelpers

  # Fix: Provide password and password_confirmation for user creation
  let(:user) do
    User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  describe 'POST /chatbot/ask' do
    context 'when user is not authenticated' do
      it 'redirects to sign in' do
        post '/chatbot/ask', params: { question: 'test question' }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'with valid authentication' do
      before { sign_in user }

      context 'when question is blank' do
        it 'returns bad request for empty question' do
          post '/chatbot/ask', params: { question: '' }
          
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)).to eq({
            'error' => 'Please provide a question'
          })
        end

        it 'returns bad request for whitespace-only question' do
          post '/chatbot/ask', params: { question: '   ' }
          
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)).to eq({
            'error' => 'Please provide a question'
          })
        end

        it 'returns bad request for nil question' do
          post '/chatbot/ask'
          
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)).to eq({
            'error' => 'Please provide a question'
          })
        end
      end

      context 'when AI service is not configured' do
        before do
          # Mock AiService to return an instance with no client
          mock_ai_service = instance_double(AiService)
          allow(AiService).to receive(:new).and_return(mock_ai_service)
          allow(mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(nil)
        end

        it 'returns service unavailable error' do
          post '/chatbot/ask', params: { question: 'What is warranty?' }
          
          expect(response).to have_http_status(:service_unavailable)
          expect(JSON.parse(response.body)).to eq({
            'error' => 'Chatbot is not configured. Please add a Gemini API key to your credentials. Visit https://makersuite.google.com/app/apikey to get one.'
          })
        end
      end

      context 'with properly configured AI service' do
        let(:search_results) do
          [
            { 'title' => 'Warranty Guide', 'url' => 'https://example.com/guide', 'snippet' => 'How warranties work' },
            { 'title' => 'Return Policy', 'url' => 'https://example.com/returns', 'snippet' => 'Return information' }
          ]
        end

        before do
          # Create real service instances but mock their methods
          @mock_ai_service = AiService.new
          @mock_search_service = GoogleSearchService.new
          
          # Mock the client to appear configured
          allow(@mock_ai_service).to receive(:instance_variable_get).with(:@client).and_return(double('client'))
          
          # Mock the service creation
          allow(AiService).to receive(:new).and_return(@mock_ai_service)
          allow(GoogleSearchService).to receive(:new).and_return(@mock_search_service)
        end

        context 'when everything works successfully' do
          it 'returns answer with search sources' do
            allow(@mock_search_service).to receive(:search_warranty_question)
              .with('What is warranty?').and_return(search_results)
            allow(@mock_ai_service).to receive(:answer_warranty_question)
              .with('What is warranty?', search_results).and_return('A warranty is a guarantee...')

            post '/chatbot/ask', params: { question: 'What is warranty?' }
            
            expect(response).to have_http_status(:ok)
            response_data = JSON.parse(response.body)
            expect(response_data['answer']).to eq('A warranty is a guarantee...')
            expect(response_data['sources']).to eq(search_results.first(3))
          end

          it 'limits sources to first 3 results' do
            large_search_results = (1..5).map do |i|
              { 'title' => "Result #{i}", 'url' => "https://example.com/#{i}", 'snippet' => "Snippet #{i}" }
            end
            
            allow(@mock_search_service).to receive(:search_warranty_question)
              .and_return(large_search_results)
            allow(@mock_ai_service).to receive(:answer_warranty_question)
              .and_return('Answer with many sources')

            post '/chatbot/ask', params: { question: 'Complex question' }
            
            expect(response).to have_http_status(:ok)
            response_data = JSON.parse(response.body)
            expect(response_data['sources'].length).to eq(3)
            expect(response_data['sources']).to eq(large_search_results.first(3))
          end

          it 'strips whitespace from question' do
            allow(@mock_search_service).to receive(:search_warranty_question)
              .with('trimmed question').and_return([])
            allow(@mock_ai_service).to receive(:answer_warranty_question)
              .with('trimmed question', []).and_return('Trimmed answer')

            post '/chatbot/ask', params: { question: '  trimmed question  ' }
            
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['answer']).to eq('Trimmed answer')
          end
        end

        context 'when search service fails' do
          before do
            allow(Rails.logger).to receive(:warn)
          end

          it 'continues without search results and logs warning' do
            allow(@mock_search_service).to receive(:search_warranty_question)
              .and_raise(StandardError, 'Search API unavailable')
            allow(@mock_ai_service).to receive(:answer_warranty_question)
              .with('test question', []).and_return('Answer without search')

            post '/chatbot/ask', params: { question: 'test question' }
            
            expect(response).to have_http_status(:ok)
            response_data = JSON.parse(response.body)
            expect(response_data['answer']).to eq('Answer without search')
            expect(response_data['sources']).to eq([])
            expect(Rails.logger).to have_received(:warn).with('Web search unavailable: Search API unavailable')
          end

          it 'handles nil search results' do
            allow(@mock_search_service).to receive(:search_warranty_question).and_return(nil)
            allow(@mock_ai_service).to receive(:answer_warranty_question)
              .with('test question', []).and_return('Answer with nil search')

            post '/chatbot/ask', params: { question: 'test question' }
            
            expect(response).to have_http_status(:ok)
            response_data = JSON.parse(response.body)
            expect(response_data['sources']).to eq([])
          end
        end

        context 'when AI service returns nil answer' do
          it 'returns internal server error' do
            allow(@mock_search_service).to receive(:search_warranty_question).and_return([])
            allow(@mock_ai_service).to receive(:answer_warranty_question).and_return(nil)

            post '/chatbot/ask', params: { question: 'unanswerable question' }
            
            expect(response).to have_http_status(:internal_server_error)
            expect(JSON.parse(response.body)).to eq({
              'error' => 'Unable to generate an answer. Please check your Gemini API key configuration.'
            })
          end
        end

        context 'when rate limit errors occur' do
          before do
            allow(Rails.logger).to receive(:error)
            # Fix: Define a proper class that can be instantiated
            unless defined?(GeminiRateLimitError)
              gemini_error_class = Class.new(StandardError) do
                attr_accessor :retry_delay
                
                def initialize(message = "Rate limited")
                  super(message)
                  @retry_delay = nil
                end
              end
              stub_const('GeminiRateLimitError', gemini_error_class)
            end
          end


        end

        context 'when other errors occur' do
          before do
            allow(Rails.logger).to receive(:error)
          end

          it 'handles 429 errors in message' do
            allow(@mock_search_service).to receive(:search_warranty_question).and_return([])
            allow(@mock_ai_service).to receive(:answer_warranty_question)
              .and_raise(StandardError, 'HTTP 429 Too Many Requests')

            post '/chatbot/ask', params: { question: 'error question' }
            
            expect(response).to have_http_status(:internal_server_error)
            response_data = JSON.parse(response.body)
            expect(response_data['error']).to include('rate-limited')
            expect(response_data['error']).to include('https://ai.dev/usage?tab=rate-limit')
            expect(Rails.logger).to have_received(:error).with('Chatbot error: HTTP 429 Too Many Requests')
          end

          it 'handles rate limit errors in message' do
            allow(@mock_search_service).to receive(:search_warranty_question).and_return([])
            allow(@mock_ai_service).to receive(:answer_warranty_question)
              .and_raise(StandardError, 'API rate limit exceeded')

            post '/chatbot/ask', params: { question: 'error question' }
            
            expect(response).to have_http_status(:internal_server_error)
            response_data = JSON.parse(response.body)
            expect(response_data['error']).to include('rate-limited')
          end

          it 'handles quota errors in message' do
            allow(@mock_search_service).to receive(:search_warranty_question).and_return([])
            allow(@mock_ai_service).to receive(:answer_warranty_question)
              .and_raise(StandardError, 'Quota exceeded for requests')

            post '/chatbot/ask', params: { question: 'error question' }
            
            expect(response).to have_http_status(:internal_server_error)
            response_data = JSON.parse(response.body)
            expect(response_data['error']).to eq('An error occurred: Quota exceeded for requests. Please check your API configuration.')
          end

          it 'handles generic errors' do
            allow(@mock_search_service).to receive(:search_warranty_question).and_return([])
            allow(@mock_ai_service).to receive(:answer_warranty_question)
              .and_raise(StandardError, 'Generic API error')

            post '/chatbot/ask', params: { question: 'error question' }
            
            expect(response).to have_http_status(:internal_server_error)
            response_data = JSON.parse(response.body)
            expect(response_data['error']).to eq('An error occurred: Generic API error. Please check your API configuration.')
            expect(Rails.logger).to have_received(:error).with('Chatbot error: Generic API error')
          end

          it 'logs error backtrace' do
            error = StandardError.new('Test error')
            error.set_backtrace(['line 1', 'line 2', 'line 3'])
            
            allow(@mock_search_service).to receive(:search_warranty_question).and_return([])
            allow(@mock_ai_service).to receive(:answer_warranty_question).and_raise(error)

            post '/chatbot/ask', params: { question: 'error question' }
            
            expect(Rails.logger).to have_received(:error).with('Chatbot error: Test error')
            expect(Rails.logger).to have_received(:error).with("line 1\nline 2\nline 3")
          end
        end
      end
    end
  end

  # Test the specific controller instantiation and method calls
  describe 'controller instance behavior' do
    let(:controller) { ChatbotController.new }
    
    before do
      allow(controller).to receive(:authenticate_user!)
      allow(controller).to receive(:params).and_return(ActionController::Parameters.new(question: 'test'))
      allow(controller).to receive(:render)
    end

    it 'can be instantiated' do
      expect(controller).to be_a(ChatbotController)
    end

    it 'responds to ask method' do
      expect(controller).to respond_to(:ask)
    end
  end
end