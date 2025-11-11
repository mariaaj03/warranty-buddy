require "google/apis/gmail_v1"
require "base64"
require "nokogiri"

class GmailFetcher
  Gmail = Google::Apis::GmailV1

  def initialize(access_token)
    @service = Gmail::GmailService.new
    @service.authorization = access_token
  end

  def service
    @service
  end

  def list_order_messages(user_id = "me", max_results = 100)
    Rails.logger.info "🔍 Fetching order messages for user: #{user_id}"

    queries = [
      "in:inbox subject:(order OR receipt OR invoice OR confirmation OR shipped OR delivered OR tracking OR e-receipt) -subject:(select OR shop OR sale OR deal OR offer OR promo OR newsletter OR marketing OR unsubscribe OR pre-order OR preorder) newer_than:2y",
      "in:inbox subject:(\"your order\" OR \"your receipt\" OR \"your e-receipt\" OR \"order #\" OR \"receipt for\" OR \"package from order\") -subject:(select OR shop OR sale OR deal OR offer OR promo OR newsletter OR marketing) newer_than:2y"
    ]

    all_messages = []
    queries.each do |query|
      Rails.logger.info "🔎 Query: #{query}"
      messages = list_messages(user_id, query, [ max_results - all_messages.length, 50 ].min)
      all_messages.concat(messages)
      break if all_messages.length >= max_results
    end

    unique_messages = all_messages.uniq { |msg| msg.id }
    Rails.logger.info "📊 Found #{unique_messages.length} unique order messages"
    unique_messages.first(max_results)
  end

  def get_message(message_id, user_id = "me")
    @service.get_user_message(user_id, message_id, format: "full")
  end

  def extract_html_from_message(message)
    payload = message.payload
    if payload.body && payload.body.data
      html = base64_decode(payload.body.data)
      return html if html.include?("<html")
    end

    if payload.parts
      result = find_html_part(payload.parts)
      return result.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    else
      ""
    end
  end

  def extract_text_from_message(message)
    payload = message.payload
    if payload.body && payload.body.data
      text = base64_decode(payload.body.data)
      return text unless text.include?("<html")
    end

    if payload.parts
      result = find_text_part(payload.parts)
      return result.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
    else
      ""
    end
  end

  def extract_attachments(message)
    attachments = []
    return attachments unless message.payload&.parts

    message.payload.parts.each do |part|
      if part.filename.present? && part.body&.attachment_id.present?
        attachments << {
          filename: part.filename,
          attachment_id: part.body.attachment_id,
          mime_type: part.mime_type
        }
      elsif part.parts
        attachments.concat(extract_attachments_from_parts(part.parts))
      end
    end

    attachments
  end

  def get_attachment(message_id, attachment_id, user_id = "me")
    @service.get_user_message_attachment(user_id, message_id, attachment_id)
  end

  private

  def list_messages(user_id, query, max_results)
    messages = []
    page_token = nil

    begin
      result = @service.list_user_messages(
        user_id,
        q: query,
        page_token: page_token,
        max_results: [ max_results, 100 ].min
      )
      messages.concat(result.messages || [])
      page_token = result.next_page_token
    end while page_token.present? && messages.length < max_results

    messages
  end

  def base64_decode(data)
    decoded = Base64.urlsafe_decode64(data)
    decoded.force_encoding("UTF-8")
    decoded.encode("UTF-8", invalid: :replace, undef: :replace)
  rescue ArgumentError
    decoded = Base64.decode64(data)
    decoded.force_encoding("UTF-8")
    decoded.encode("UTF-8", invalid: :replace, undef: :replace)
  end

  def find_html_part(parts)
    parts.each do |part|
      if part.mime_type == "text/html" && part.body && part.body.data
        html = base64_decode(part.body.data)
        return html.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
      elsif part.parts
        result = find_html_part(part.parts)
        return result if result.present?
      end
    end
    ""
  end

  def find_text_part(parts)
    parts.each do |part|
      if part.mime_type == "text/plain" && part.body && part.body.data
        text = base64_decode(part.body.data)
        return text.to_s.force_encoding("UTF-8").encode("UTF-8", invalid: :replace, undef: :replace)
      elsif part.parts
        result = find_text_part(part.parts)
        return result if result.present?
      end
    end
    ""
  end

  def extract_attachments_from_parts(parts)
    attachments = []
    parts.each do |part|
      if part.filename.present? && part.body&.attachment_id.present?
        attachments << {
          filename: part.filename,
          attachment_id: part.body.attachment_id,
          mime_type: part.mime_type
        }
      elsif part.parts
        attachments.concat(extract_attachments_from_parts(part.parts))
      end
    end
    attachments
  end
end
