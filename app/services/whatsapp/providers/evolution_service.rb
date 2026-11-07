# frozen_string_literal: true

class Whatsapp::Providers::EvolutionService < Whatsapp::Providers::BaseService
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
    # Provedores não oficiais não precisam de aprovação de templates;
    # envia o conteúdo diretamente como mensagem comum.
    send_message(phone_number, message)
  end

  def sync_templates
    whatsapp_channel.mark_message_templates_updated
  end

  def validate_provider_config?
    return true if api_host.present? && api_key.present? && instance_name.present?

    false
  end

  def error_message(response)
    response.parsed_response['message'] || response.parsed_response['error'] || response.body
  end

  private

  def api_host
    whatsapp_channel.provider_config['api_host'] || ENV.fetch('EVOLUTION_API_HOST', nil)
  end

  def api_key
    whatsapp_channel.provider_config['api_key'] || ENV.fetch('EVOLUTION_API_KEY', nil)
  end

  def instance_name
    whatsapp_channel.provider_config['instance_name'] || whatsapp_channel.phone_number
  end

  def normalize_number(number)
    clean = number.to_s.delete('+')
    normalizer = Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer.new
    normalizer.handles_country?(clean) ? normalizer.normalize(clean) : clean
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'apikey' => api_key
    }
  end

  def send_text_message(phone_number, message)
    url = "#{api_host}/message/sendText/#{instance_name}"
    body = {
      number: phone_number,
      text: message.content,
      options: {
        delay: 1200,
        presence: 'composing'
      }
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json)
    process_evolution_response(response, message)
  end

  def send_attachment_message(phone_number, message)
    attachment = message.attachments.first
    return if attachment.blank?

    file_url = attachment.download_url

    if attachment.audio?
      send_audio_voice_note(phone_number, file_url, message)
    else
      send_media_file(phone_number, file_url, attachment, message)
    end
  end

  def send_audio_voice_note(phone_number, audio_url, message)
    # Envia áudio como PTT (nota de voz com microfone verde)
    url = "#{api_host}/message/sendWhatsAppAudio/#{instance_name}"
    body = {
      number: phone_number,
      audio: audio_url,
      options: {
        delay: 1500,
        presence: 'recording'
      }
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json)
    process_evolution_response(response, message)
  end

  def send_media_file(phone_number, file_url, attachment, message)
    url = "#{api_host}/message/sendMedia/#{instance_name}"
    body = {
      number: phone_number,
      media: file_url,
      mediatype: media_type_for(attachment),
      caption: message.content.presence || '',
      fileName: attachment.file.filename.to_s
    }

    response = HTTParty.post(url, headers: headers, body: body.to_json)
    process_evolution_response(response, message)
  end

  def media_type_for(attachment)
    if attachment.image?
      'image'
    elsif attachment.video?
      'video'
    else
      'document'
    end
  end

  def process_evolution_response(response, message)
    if response.success?
      parsed = response.parsed_response
      msg_id = parsed.dig('key', 'id') || parsed['messageId'] || parsed['id']
      message.update!(source_id: msg_id) if msg_id.present?
      msg_id
    else
      handle_error(response, message)
      nil
    end
  end
end

