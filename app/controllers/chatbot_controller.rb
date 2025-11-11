class ChatbotController < ApplicationController
  before_action :authenticate_user!

  def ask
    question = params[:question]&.strip

    if question.blank?
      render json: { error: "Please provide a question" }, status: :bad_request
      return
    end

    begin
      search_service = GoogleSearchService.new
      search_results = search_service.search_warranty_question(question)

      ai_service = AiService.new
      answer = ai_service.answer_warranty_question(question, search_results)

      if answer
        render json: { answer: answer, sources: search_results.first(3) }
      else
        render json: { error: "Unable to generate an answer. Please try again." }, status: :internal_server_error
      end
    rescue => e
      Rails.logger.error "Chatbot error: #{e.message}"
      render json: { error: "An error occurred. Please try again." }, status: :internal_server_error
    end
  end
end

