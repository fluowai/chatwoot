# frozen_string_literal: true

class Whatsapp::Providers::WhatsmeowService < Whatsapp::Providers::BaseService
  def send_message(phone_number, message)
    @message = message
    normalized_number = normalize_number(phone_number)

    if message.attachments.present?
      send_attachment_message(normalized_number, message)
    else
      send_text_message(normalized_number, message)
    end
  end

  def send_template(phone_number, _template_info, message)
    send_message(phone_number, message)
  end

  def sync_templates
    whatsapp_channel.mark_message_templates_updated
  end

  def validate_provider_config?
    bridge_url.present?
  end

  def error_message(response)
    parsed = response.parsed_response
    parsed.is_a?(Hash) ? (parsed['message'] || parsed['error'] || response.body) : response.body.to_s
  end

  def connection_status
    url = "#{bridge_url}/api/v1/session/status?session=#{ERB::Util.url_encode(session_id)}"
    response = HTTParty.get(url, headers: headers, timeout: 10)
    return { state: 'error', error: error_message(response) } unless response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    { state: parsed['state'] || (parsed['connected'] ? 'open' : 'close'), instance: session_id }
  rescue StandardError => e
    { state: 'unreachable', error: e.message }
  end

  def fetch_qr_code
    url = "#{bridge_url}/api/v1/session/qr?session=#{ERB::Util.url_encode(session_id)}"
    response = HTTParty.get(url, headers: headers, timeout: 15)
    return { error: error_message(response) } unless response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    {
      base64: parsed['base64'] || parsed['qr_base64'],
      code: parsed['code'] || parsed['qr'],
      pairing_code: parsed['pairing_code']
    }.compact
  rescue StandardError => e
    { error: e.message }
  end

  private

  def bridge_url
    host = whatsapp_channel.provider_config['api_host'].presence ||
           whatsapp_channel.provider_config['bridge_url'].presence ||
           ENV.fetch('WHATSMEOW_BRIDGE_URL', 'http://localhost:8083')
    host.chomp('/')
  end

  def auth_token
    whatsapp_channel.provider_config['api_key'].presence || ENV.fetch('WHATSMEOW_AUTH_TOKEN', nil)
  end

  def session_id
    whatsapp_channel.provider_config['instance_name'].presence ||
      whatsapp_channel.provider_config['session_id'].presence ||
      whatsapp_channel.phone_number.to_s.delete('+')
  end

  def normalize_number(number)
    clean = number.to_s.gsub(/\D/, '')
    normalizer = Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer.new
    normalizer.handles_country?(clean) ? normalizer.normalize(clean) : clean
  end

  def headers
    h = { 'Content-Type' => 'application/json' }
    h['Authorization'] = "Bearer #{auth_token}" if auth_token.present?
    h
  end

  def send_text_message(phone_number, message)
    url = "#{bridge_url}/api/v1/send/text"
    body = {
      session: session_id,
      recipient: "#{phone_number}@s.whatsapp.net",
      text: message.outgoing_content.presence || message.content.to_s
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json, timeout: 20)
    process_whatsmeow_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    return if attachment.blank?

    file_url = attachment.download_url
    url = "#{bridge_url}/api/v1/send/media"

    body = {
      session: session_id,
      recipient: "#{phone_number}@s.whatsapp.net",
      url: file_url,
      caption: message.outgoing_content.presence || message.content.to_s,
      type: attachment.file_type,
      ptt: attachment.audio?
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json, timeout: 30)
    process_whatsmeow_response(response, message)
  end

  def process_whatsmeow_response(response, message)
    if response.success?
      parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
      msg_id = parsed['id'] || parsed['message_id']
      message.update!(source_id: msg_id) if msg_id.present?
      msg_id
    else
      handle_error(response, message)
      nil
    end
  end
end
