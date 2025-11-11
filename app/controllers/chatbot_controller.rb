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
        Rails.logger.warn "Web search unavailable: #{e.message}"
      end

      answer = ai_service.answer_warranty_question(question, search_results)

      if answer
        render json: { answer: answer, sources: search_results.first(3) || [] }
      else
        render json: { 
          error: "Unable to generate an answer. Please check your Gemini API key configuration."
        }, status: :internal_server_error
      end
    rescue => e
      Rails.logger.error "Chatbot error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { 
        error: "An error occurred: #{e.message}. Please check your API configuration."
      }, status: :internal_server_error
    end
  end
end

