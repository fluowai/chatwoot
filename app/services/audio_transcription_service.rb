# frozen_string_literal: true

class AudioTranscriptionService
  pattr_initialize [:attachment!]

  def self.configured?
    groq_api_key.present? || openai_api_key.present?
  end

  def self.groq_api_key
    ENV['GROQ_API_KEY'].presence || GlobalConfigService.load('GROQ_API_KEY', nil).presence
  end

  def self.openai_api_key
    ENV['OPENAI_API_KEY'].presence || GlobalConfigService.load('CAPTAIN_OPEN_AI_API_KEY', nil).presence
  end

  def perform
    return if attachment.blank? || !attachment.audio?
    return if api_key.blank?

    transcribed_text = transcribe_audio
    return if transcribed_text.blank?

    current_meta = attachment.meta || {}
    attachment.update!(meta: current_meta.merge('transcribed_text' => transcribed_text))

    broadcast_transcript_update
    transcribed_text
  rescue StandardError => e
    Rails.logger.error "[AUDIO_TRANSCRIPTION] Failed for attachment #{attachment&.id}: #{e.message}"
    nil
  end

  private

  def using_groq?
    self.class.groq_api_key.present?
  end

  def api_key
    self.class.groq_api_key || self.class.openai_api_key
  end

  def endpoint_url
    if using_groq?
      'https://api.groq.com/openai/v1/audio/transcriptions'
    else
      'https://api.openai.com/v1/audio/transcriptions'
    end
  end

  def model_name
    if using_groq?
      'whisper-large-v3'
    else
      'whisper-1'
    end
  end

  def transcribe_audio
    attachment.file.open do |tempfile|
      response = HTTParty.post(
        endpoint_url,
        headers: {
          'Authorization' => "Bearer #{api_key}"
        },
        body: {
          file: tempfile,
          model: model_name,
          language: 'pt',
          response_format: 'json'
        },
        timeout: 45
      )

      return response.parsed_response['text'] if response.success?

      Rails.logger.warn "[AUDIO_TRANSCRIPTION] API Error: #{response.code} #{response.body}"
      nil
    end
  end

  def broadcast_transcript_update
    message = attachment.message
    return if message.blank?

    ActionCable.server.broadcast(
      "account_#{message.account_id}",
      {
        event: 'message.updated',
        data: message.push_event_data
      }
    )
  end
end
