class ChatbotController < ApplicationController
  before_action :authenticate_user!

  def ask
    question = params[:question]&.strip

    if question.blank?
      render json: { error: "Please provide a question" }, status: :bad_request
      return
    end

    begin
      ai_service = AiService.new
      
      unless ai_service.instance_variable_get(:@client)
        render json: { 
          error: "Chatbot is not configured. Please add a Gemini API key to your credentials. Visit https://makersuite.google.com/app/apikey to get one."
        }, status: :service_unavailable
        return
      end

      search_results = []
      begin
        search_service = GoogleSearchService.new
        search_results = search_service.search_warranty_question(question) || []
      rescue => e
        # Web search unavailable, continue without it
      end

      answer = ai_service.answer_warranty_question(question, search_results)

      if answer
        render json: { answer: answer, sources: search_results.first(3) || [] }
      else
        render json: { 
          error: "Unable to generate an answer. Please check your Gemini API key configuration."
        }, status: :internal_server_error
      end
    rescue GeminiRateLimitError => e
      user_message = "The AI service is currently rate-limited. This usually means you've made too many requests too quickly. If this persists, you may need to check your Gemini API quota."
      render json: { 
        error: user_message
      }, status: :too_many_requests
    rescue => e
      error_message = if e.message.include?("429") || e.message.include?("rate limit") || e.message.include?("quota")
        "The AI service is currently rate-limited. Please wait a moment and try again. If this persists, check your Gemini API quota at https://ai.dev/usage?tab=rate-limit"
      else
        "An error occurred: #{e.message}. Please check your API configuration."
      end
      
      render json: { 
        error: error_message
      }, status: :internal_server_error
    end
  end
end

