# frozen_string_literal: true

class Whatsapp::Providers::BaileysService < Whatsapp::Providers::BaseService
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
    gateway_url.present?
  end

  def error_message(response)
    parsed = response.parsed_response
    parsed.is_a?(Hash) ? (parsed['message'] || parsed['error'] || response.body) : response.body.to_s
  end

  def connection_status
    url = "#{gateway_url}/sessions/#{ERB::Util.url_encode(session_id)}/status"
    response = HTTParty.get(url, headers: headers, timeout: 10)
    return { state: 'error', error: error_message(response) } unless response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    { state: parsed['status'] || parsed['state'] || 'open', instance: session_id }
  rescue StandardError => e
    { state: 'unreachable', error: e.message }
  end

  def fetch_qr_code
    url = "#{gateway_url}/sessions/#{ERB::Util.url_encode(session_id)}/qr"
    response = HTTParty.get(url, headers: headers, timeout: 15)
    return { error: error_message(response) } unless response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    {
      base64: parsed['qr'] || parsed['base64'],
      code: parsed['code'],
      pairing_code: parsed['pairingCode']
    }.compact
  rescue StandardError => e
    { error: e.message }
  end

  private

  def gateway_url
    host = whatsapp_channel.provider_config['api_host'].presence ||
           whatsapp_channel.provider_config['gateway_url'].presence ||
           ENV.fetch('BAILEYS_GATEWAY_URL', 'http://localhost:8082')
    host.chomp('/')
  end

  def auth_token
    whatsapp_channel.provider_config['api_key'].presence || ENV.fetch('BAILEYS_AUTH_TOKEN', nil)
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
    url = "#{gateway_url}/chats/send?session=#{ERB::Util.url_encode(session_id)}"
    body = {
      receiver: "#{phone_number}@s.whatsapp.net",
      message: {
        text: message.outgoing_content.presence || message.content.to_s
      }
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json, timeout: 20)
    process_baileys_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    return if attachment.blank?

    file_url = attachment.download_url
    url = "#{gateway_url}/chats/send?session=#{ERB::Util.url_encode(session_id)}"

    payload_message = if attachment.audio?
                        {
                          audio: { url: file_url },
                          mimetype: 'audio/ogg; codecs=opus',
                          ptt: true
                        }
                      elsif attachment.image?
                        {
                          image: { url: file_url },
                          caption: message.outgoing_content.presence || message.content.to_s
                        }
                      elsif attachment.video?
                        {
                          video: { url: file_url },
                          caption: message.outgoing_content.presence || message.content.to_s
                        }
                      else
                        {
                          document: { url: file_url },
                          fileName: attachment.file.filename.to_s,
                          mimetype: attachment.file.content_type
                        }
                      end

    body = {
      receiver: "#{phone_number}@s.whatsapp.net",
      message: payload_message
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json, timeout: 30)
    process_baileys_response(response, message)
  end

  def process_baileys_response(response, message)
    if response.success?
      parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
      msg_id = parsed.dig('key', 'id') || parsed['id']
      message.update!(source_id: msg_id) if msg_id.present?
      msg_id
    else
      handle_error(response, message)
      nil
    end
  end
end
