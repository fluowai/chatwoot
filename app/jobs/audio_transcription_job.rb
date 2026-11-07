# frozen_string_literal: true

class AudioTranscriptionJob < ApplicationJob
  queue_as :low

  def perform(attachment)
    AudioTranscriptionService.new(attachment: attachment).perform
  end
end

