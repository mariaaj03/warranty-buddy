class DashboardController < ApplicationController
  protect_from_forgery with: :exception
  before_action :authenticate_user!
  before_action :set_gmail_status

  def index

    @search_term = params[:search]
    @status_filter = params[:status]
    @merchant_filter = params[:merchant]
    @sort_by = params[:sort] || "expiry_date"

    @warranties = current_user.products

    @warranties = @warranties.search(@search_term) if @search_term.present?

    case @status_filter
    when "active"
      @warranties = @warranties.active
    when "expired"
      @warranties = @warranties.expired
    when "expiring_soon"
      @warranties = @warranties.expiring_soon
    end

    @warranties = @warranties.by_merchant(@merchant_filter) if @merchant_filter.present?
    @merchants = @warranties.distinct.pluck(:merchant).compact.sort

    case @sort_by
    when "expiry_date"
      @warranties = @warranties.order(:purchase_date, :warranty_months)
    when "product_name"
      @warranties = @warranties.order(:product_name)
    when "purchase_date"
      @warranties = @warranties.order(:purchase_date)
    when "merchant"
      @warranties = @warranties.order(:merchant)
    end

    @gmail_messages = []
  end


  def upload
    if params[:product].blank?
      respond_to do |format|
        format.html { flash[:alert] = "Missing product"; redirect_to dashboard_path }
        format.json { head :bad_request }
      end
      return
    end

    unless @gmail_connected
      redirect_to dashboard_path, alert: "Please connect your Gmail account first"
      return
    end

    purchase_date = begin
      Date.parse(params[:purchase_date])
    rescue ArgumentError, TypeError
      Date.today
    end

    warranty_months = params[:warranty_length].presence
    warranty_months = warranty_months.to_i if warranty_months
    warranty_months = 0 if warranty_months && warranty_months.negative?

    current_user.products.create!(
      product_name: params[:product],
      merchant: params[:merchant].presence || "",
      purchase_date: purchase_date,
      warranty_months: warranty_months,
      issue_description: params[:issue_description]
    )

    redirect_to dashboard_path
  end

  def api_warranties
    warranties = current_user.products

    render json: warranties.map { |p|
      {
        id: p.id,
        product: p.product_name,
        merchant: p.merchant,
        purchase_date: p.purchase_date,
        warranty_length_months: p.warranty_months
      }
    }
  end

  def api_health
    render json: { ok: true, gmail_connected: @gmail_connected }, status: :ok
  end

  def reset
    current_user.update(gmail_token: nil, gmail_refresh_token: nil)
    head :ok
  end

  def disconnect_gmail
    current_user.update(gmail_token: nil, gmail_refresh_token: nil)
    redirect_to dashboard_path
  end

  def parse_gmail_receipts
    return redirect_to dashboard_path unless @gmail_connected

    begin
      gmail_service = GmailService.new(current_user.gmail_token)
      parsed_receipts = gmail_service.parse_receipt_emails

      created_count = 0
      parsed_receipts.each do |receipt_data|
        next if receipt_data[:product_name].blank?

        existing_product = current_user.products.find_by(raw_email_id: receipt_data[:raw_email_id])
        next if existing_product
        next if receipt_data[:product_name].blank? || receipt_data[:purchase_date].blank?

        current_user.products.create!(
          product_name: receipt_data[:product_name],
          merchant: receipt_data[:merchant].presence || "",
          purchase_date: receipt_data[:purchase_date] || Date.today,
          warranty_months: receipt_data[:warranty_months] || 12,
          warranty_type: receipt_data[:warranty_type],
          return_policy_days: receipt_data[:return_policy_days],
          return_deadline: receipt_data[:return_deadline],
          source: receipt_data[:source],
          raw_email_id: receipt_data[:raw_email_id]
        )
        created_count += 1
      end

      redirect_to dashboard_path
    rescue => e
      Rails.logger.error "Gmail parsing failed: #{e.message}"
      message = e.message.to_s
      if message.include?("PERMISSION_DENIED") || message.include?("SERVICE_DISABLED") || message.include?("accessNotConfigured")
        alert_msg = "Gmail API is disabled for your Google Cloud project. Please enable it here (must be owner): https://console.cloud.google.com/apis/library/gmail.googleapis.com?project=#{Rails.application.credentials.dig(:google, :project_id) || 'YOUR_PROJECT_ID'}"
        redirect_to dashboard_path
      else
        redirect_to dashboard_path
      end
    end
  end

  def check_warranty_eligibility
    unless @gmail_connected
      respond_to do |format|
        format.json { render json: { error: "Gmail not connected" }, status: :unauthorized }
        format.html { redirect_to dashboard_path, alert: "Please connect your Gmail account first" }
      end
      return
    end

    product = current_user.products.find(params[:product_id])
    issue_description = params[:issue_description]

    if issue_description.blank?
      respond_to do |format|
        format.json { render json: { error: "Please describe the issue" }, status: :bad_request }
        format.html { redirect_to root_path, alert: "Please describe the issue" }
      end
      return
    end

    result = product.check_warranty_eligibility(issue_description)

    respond_to do |format|
      format.json { render json: result }
      format.html { redirect_to dashboard_path, notice: result["reasoning"] }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.json { render json: { error: "Product not found" }, status: :not_found }
      format.html { redirect_to dashboard_path, alert: "Product not found" }
    end
  end

  def lookup_warranty_info
    product_name = params[:product_name]
    merchant = params[:merchant]

    ai_service = AiService.new
    warranty_info = ai_service.lookup_warranty_info(product_name, merchant)

    respond_to do |format|
      format.json { render json: warranty_info }
    end
  end

  def delete_warranty
    product = current_user.products.find_by(id: params[:id])
    if product
      product.destroy
      head :ok
    else
      head :not_found
    end
  end

  def update_warranty
    product = current_user.products.find_by(id: params[:id])
    if product
      purchase_date = nil
      if params[:purchase_date].present?
        begin
          purchase_date = Date.parse(params[:purchase_date])
        rescue ArgumentError => e
          Rails.logger.error "Date parsing error: #{e.message}, date: #{params[:purchase_date]}"
          head :bad_request
          return
        end
      end

      product.update!(
        product_name: params[:product_name],
        merchant: params[:merchant],
        purchase_date: purchase_date,
        warranty_months: params[:warranty_months].to_i
      )
      head :ok
    else
      head :not_found
    end
  end

  private

  def set_gmail_status
    @gmail_connected = current_user&.gmail_connected?
  end
end
