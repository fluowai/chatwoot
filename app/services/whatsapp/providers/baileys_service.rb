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
    response.parsed_response['message'] || response.parsed_response['error'] || response.body
  end

  private

  def gateway_url
    whatsapp_channel.provider_config['gateway_url'] || ENV.fetch('BAILEYS_GATEWAY_URL', 'http://localhost:8082')
  end

  def auth_token
    whatsapp_channel.provider_config['api_key'] || ENV.fetch('BAILEYS_AUTH_TOKEN', nil)
  end

  def session_id
    whatsapp_channel.provider_config['session_id'] || whatsapp_channel.phone_number
  end

  def normalize_number(number)
    clean = number.to_s.delete('+')
    normalizer = Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer.new
    normalizer.handles_country?(clean) ? normalizer.normalize(clean) : clean
  end

  def headers
    h = { 'Content-Type' => 'application/json' }
    h['Authorization'] = "Bearer #{auth_token}" if auth_token.present?
    h
  end

  def send_text_message(phone_number, message)
    url = "#{gateway_url}/chats/send?session=#{session_id}"
    body = {
      receiver: "#{phone_number}@s.whatsapp.net",
      message: {
        text: message.content
      }
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json)
    process_baileys_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    return if attachment.blank?

    file_url = attachment.download_url
    url = "#{gateway_url}/chats/send?session=#{session_id}"

    payload_message = if attachment.audio?
                        {
                          audio: { url: file_url },
                          mimetype: 'audio/ogg; codecs=opus',
                          ptt: true
                        }
                      elsif attachment.image?
                        {
                          image: { url: file_url },
                          caption: message.content.presence || ''
                        }
                      elsif attachment.video?
                        {
                          video: { url: file_url },
                          caption: message.content.presence || ''
                        }
                      else
                        {
                          document: { url: file_url },
                          fileName: attachment.file.filename.to_s,
                          mimetype: attachment.file_type
                        }
                      end

    body = {
      receiver: "#{phone_number}@s.whatsapp.net",
      message: payload_message
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json)
    process_baileys_response(response, message)
  end

  def process_baileys_response(response, message)
    if response.success?
      parsed = response.parsed_response
      msg_id = parsed.dig('key', 'id') || parsed['id']
      message.update!(source_id: msg_id) if msg_id.present?
      msg_id
    else
      handle_error(response, message)
      nil
    end
  end
end

