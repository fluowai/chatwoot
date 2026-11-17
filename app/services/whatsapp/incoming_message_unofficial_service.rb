# frozen_string_literal: true

class Whatsapp::IncomingMessageUnofficialService
  STATUS_MAP = {
    0 => 'failed',
    3 => 'delivered',
    4 => 'read',
    5 => 'read',
    'ERROR' => 'failed',
    'FAILED' => 'failed',
    'DELIVERY_ACK' => 'delivered',
    'DELIVERED' => 'delivered',
    'READ' => 'read',
    'PLAYED' => 'read'
  }.freeze

  MEDIA_MESSAGE_KEYS = %w[
    imageMessage
    audioMessage
    videoMessage
    documentMessage
    documentWithCaptionMessage
    stickerMessage
  ].freeze

  pattr_initialize [:inbox!, :params!]

  def perform
    payload = params.with_indifferent_access
    event_name = normalize_event_name(payload[:event])

    if status_event?(event_name, payload)
      process_status_updates(payload)
    else
      process_incoming_messages(payload)
    end
  end

  private

  def normalize_event_name(event)
    event.to_s.downcase.tr('_', '.')
  end

  def status_event?(event_name, payload)
    %w[messages.update receipt message.ack].include?(event_name) ||
      (event_name.blank? && payload[:statuses].present?)
  end

  def process_status_updates(payload)
    updates = extract_status_entries(payload)
    updates.each do |entry|
      source_id = entry[:id]
      mapped_status = STATUS_MAP[entry[:status]]
      next if source_id.blank? || mapped_status.blank?

      message = inbox.messages.find_by(source_id: source_id.to_s)
      next unless message

      Messages::StatusUpdateService.new(message, mapped_status).perform
    end
  rescue StandardError => e
    Rails.logger.error "[WHATSAPP_UNOFFICIAL] Status update error: #{e.message}"
  end

  def extract_status_entries(payload)
    data = payload[:data]
    if data.is_a?(Array)
      data.map { |item| parse_single_status(item) }.compact
    elsif data.is_a?(Hash)
      [parse_single_status(data)].compact
    elsif payload[:Info].present? && payload[:Type].present?
      ids = Array(payload[:MessageIDs] || payload.dig(:Info, :ID))
      ids.map { |id| { id: id, status: payload[:Type].to_s.upcase } }
    else
      []
    end
  end

  def parse_single_status(item)
    msg_id = item[:keyId] || item.dig(:key, :id) || item[:id]
    raw_status = item[:status] || item.dig(:update, :status)
    return if msg_id.blank? || raw_status.blank?

    { id: msg_id, status: raw_status }
  end

  def process_incoming_messages(payload)
    envelopes = extract_message_envelopes(payload)
    envelopes.each do |envelope|
      process_single_envelope(envelope)
    end
  end

  def extract_message_envelopes(payload)
    if payload[:Info].present? && payload[:Message].present?
      [normalize_whatsmeow_envelope(payload)]
    elsif payload[:data].is_a?(Hash) && payload.dig(:data, :messages).is_a?(Array)
      payload.dig(:data, :messages).map { |msg| normalize_baileys_envelope(msg, payload[:data]) }
    elsif payload[:data].is_a?(Array)
      payload[:data].map { |msg| normalize_baileys_envelope(msg, payload) }
    elsif payload[:data].is_a?(Hash) && payload.dig(:data, :key).present?
      [normalize_baileys_envelope(payload[:data], payload)]
    elsif payload[:messages].is_a?(Array)
      payload[:messages].map { |msg| normalize_baileys_envelope(msg, payload) }
    else
      []
    end.compact
  end

  def normalize_baileys_envelope(item, root_payload)
    key = item[:key] || {}
    raw_msg = unwrap_ephemeral_or_view_once(item[:message] || {})
    remote_jid = resolve_jid(key, item, root_payload)
    return if skip_jid?(remote_jid)

    {
      source_id: key[:id].to_s,
      remote_jid: remote_jid,
      from_me: ActiveModel::Type::Boolean.new.cast(key[:fromMe]),
      push_name: item[:pushName] || root_payload[:pushName],
      message: raw_msg,
      base64: item[:base64] || raw_msg[:base64] || root_payload.dig(:data, :base64),
      media_url: item[:mediaUrl] || raw_msg[:mediaUrl],
      raw_key: key
    }
  end

  def normalize_whatsmeow_envelope(payload)
    info = payload[:Info] || {}
    chat_jid = info[:Chat].presence || info[:Sender].to_s
    return if skip_jid?(chat_jid)

    sender_jid = ActiveModel::Type::Boolean.new.cast(info[:IsFromMe]) ? chat_jid : (info[:SenderAlt].presence || info[:Sender].presence || chat_jid)
    raw_msg = unwrap_ephemeral_or_view_once(payload[:Message] || {})

    {
      source_id: info[:ID].to_s,
      remote_jid: sender_jid,
      from_me: ActiveModel::Type::Boolean.new.cast(info[:IsFromMe]),
      push_name: info[:PushName],
      message: raw_msg,
      base64: payload[:Base64] || raw_msg[:base64],
      media_url: payload[:MediaURL] || raw_msg[:url],
      raw_key: { id: info[:ID], remoteJid: chat_jid, fromMe: info[:IsFromMe] }
    }
  end

  def unwrap_ephemeral_or_view_once(msg)
    return msg unless msg.is_a?(Hash)

    msg.dig(:ephemeralMessage, :message) ||
      msg.dig(:viewOnceMessage, :message) ||
      msg.dig(:viewOnceMessageV2, :message) ||
      msg.dig(:documentWithCaptionMessage, :message) ||
      msg
  end

  def resolve_jid(key, item, root_payload)
    candidates = [
      key[:remoteJidAlt],
      item[:remoteJidAlt],
      key[:senderPn],
      item[:senderPn],
      root_payload[:sender],
      key[:remoteJid]
    ].compact_blank

    phone_jid = candidates.find { |jid| jid.to_s.include?('@s.whatsapp.net') || jid.to_s.match?(/\A\+?\d{10,15}\z/) }
    phone_jid || key[:remoteJid].to_s
  end

  def skip_jid?(jid)
    return true if jid.blank?
    return true if jid.include?('status@broadcast') || jid.include?('@newsletter')
    return true if jid.include?('@g.us') && !allow_group_messages?

    false
  end

  def allow_group_messages?
    ActiveModel::Type::Boolean.new.cast(inbox.channel.provider_config['allow_groups'])
  end

  def process_single_envelope(envelope)
    source_id = envelope[:source_id]
    return if source_id.blank?
    return if reaction_or_protocol_only?(envelope[:message])
    return if Message.exists?(source_id: source_id)
    return unless Whatsapp::MessageDedupLock.new(source_id).acquire!

    phone_digits = extract_phone_digits(envelope[:remote_jid])
    return if phone_digits.blank?

    normalized_phone = normalize_brazil_phone(phone_digits)
    contact_inbox = find_or_create_contact_inbox(normalized_phone, envelope)
    return unless contact_inbox

    contact = contact_inbox.contact
    return if contact.blocked? && !envelope[:from_me]

    ActiveRecord::Base.transaction do
      conversation = find_or_create_conversation(contact_inbox)
      build_and_save_message(conversation, contact, envelope)
    end
  end

  def reaction_or_protocol_only?(msg)
    return true if msg.blank?

    ignored_keys = %w[reactionMessage protocolMessage senderKeyDistributionMessage messageContextInfo]
    (msg.keys.map(&:to_s) - ignored_keys).empty?
  end

  def extract_phone_digits(jid)
    raw = jid.to_s.split('@').first.to_s.split(':').first
    digits = raw.gsub(/\D/, '')
    digits.presence
  end

  def normalize_brazil_phone(digits)
    normalizer = Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer.new
    normalizer.handles_country?(digits) ? normalizer.normalize(digits) : digits
  end

  def find_or_create_contact_inbox(normalized_phone, envelope)
    e164_phone = "+#{normalized_phone}"
    display_name = if envelope[:from_me]
                     e164_phone
                   else
                     envelope[:push_name].presence || e164_phone
                   end

    ContactInboxWithContactBuilder.new(
      source_id: normalized_phone,
      inbox: inbox,
      contact_attributes: {
        name: display_name,
        phone_number: e164_phone
      }
    ).perform
  end

  def find_or_create_conversation(contact_inbox)
    conversations = contact_inbox.conversations
    existing = if inbox.lock_to_single_conversation
                 conversations.last
               else
                 conversations.where.not(status: :resolved).last
               end
    return existing if existing

    Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: contact_inbox.contact_id,
      contact_inbox_id: contact_inbox.id
    )
  end

  def build_and_save_message(conversation, contact, envelope)
    msg_payload = envelope[:message]
    from_me = envelope[:from_me]
    text_content = extract_text_content(msg_payload)
    content_attrs = build_content_attributes(conversation, msg_payload, from_me)

    message = conversation.messages.build(
      content: text_content,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: from_me ? :outgoing : :incoming,
      status: from_me ? :delivered : :sent,
      sender: from_me ? nil : contact,
      source_id: envelope[:source_id],
      content_attributes: content_attrs
    )

    attach_media_if_present(message, envelope)
    attach_location_if_present(message, msg_payload)
    message.save!
  end

  def extract_text_content(msg)
    msg[:conversation].presence ||
      msg.dig(:extendedTextMessage, :text).presence ||
      msg.dig(:imageMessage, :caption).presence ||
      msg.dig(:videoMessage, :caption).presence ||
      msg.dig(:documentMessage, :caption).presence ||
      msg.dig(:buttonsResponseMessage, :selectedDisplayText).presence ||
      msg.dig(:listResponseMessage, :title).presence ||
      msg.dig(:templateButtonReplyMessage, :selectedDisplayText).presence ||
      msg.dig(:contactMessage, :displayName).presence
  end

  def build_content_attributes(conversation, msg_payload, from_me)
    attrs = from_me ? { external_echo: true } : {}
    stanza_id = extract_quoted_stanza_id(msg_payload)
    if stanza_id.present?
      attrs[:in_reply_to_external_id] = stanza_id
      replied = Whatsapp::InReplyToMessageFinder.new(conversation: conversation, source_id: stanza_id).perform
      attrs[:in_reply_to] = replied.id if replied
    end
    attrs
  end

  def extract_quoted_stanza_id(msg)
    msg.values.each do |val|
      next unless val.is_a?(Hash)

      stanza = val.dig(:contextInfo, :stanzaId)
      return stanza if stanza.present?
    end
    nil
  end

  def attach_location_if_present(message, msg)
    loc = msg[:locationMessage] || msg[:liveLocationMessage]
    return if loc.blank?

    title = [loc[:name], loc[:address]].compact_blank.join(', ').first(255)
    message.attachments.new(
      account_id: message.account_id,
      file_type: :location,
      coordinates_lat: loc[:degreesLatitude].to_f,
      coordinates_long: loc[:degreesLongitude].to_f,
      fallback_title: title
    )
  end

  def attach_media_if_present(message, envelope)
    msg = envelope[:message]
    media_key = MEDIA_MESSAGE_KEYS.find { |k| msg[k].present? }
    return if media_key.blank?

    media_node = msg[media_key]
    file_io, filename, content_type = resolve_media_io(media_key, media_node, envelope)
    return if file_io.blank?

    message.attachments.new(
      account_id: message.account_id,
      file_type: map_attachment_type(media_key),
      file: {
        io: file_io,
        filename: filename,
        content_type: content_type
      }
    )
  end

  def map_attachment_type(media_key)
    case media_key
    when 'imageMessage', 'stickerMessage' then :image
    when 'audioMessage' then :audio
    when 'videoMessage' then :video
    else :file
    end
  end

  def resolve_media_io(media_key, media_node, envelope)
    mimetype = (media_node[:mimetype].presence || default_mimetype(media_key)).split(';').first.strip
    ext = Rack::Mime::MIME_TYPES.invert[mimetype]&.delete_prefix('.') || default_extension(media_key)
    filename = media_node[:fileName].presence || "#{media_key.sub('Message', '')}_#{envelope[:source_id]}.#{ext}"

    raw_base64 = envelope[:base64].presence || fetch_base64_from_evolution(envelope[:raw_key])
    if raw_base64.present?
      clean_b64 = raw_base64.sub(%r{\Adata:[^;]+;base64,}, '')
      decoded = Base64.decode64(clean_b64)
      return [StringIO.new(decoded), filename, mimetype]
    end

    direct_url = envelope[:media_url].presence || non_encrypted_url(media_node[:url])
    if direct_url.present?
      downloaded = Down.download(direct_url)
      return [downloaded, downloaded.original_filename.presence || filename, downloaded.content_type.presence || mimetype]
    end

    nil
  rescue StandardError => e
    Rails.logger.warn "[WHATSAPP_UNOFFICIAL] Media download failed for #{envelope[:source_id]}: #{e.message}"
    nil
  end

  def non_encrypted_url(url)
    return if url.blank? || url.to_s.include?('.enc')

    url
  end

  def fetch_base64_from_evolution(raw_key)
    return unless inbox.channel.provider == 'evolution' && raw_key.present?

    service = inbox.channel.provider_service
    service.respond_to?(:fetch_media_base64) ? service.fetch_media_base64(raw_key) : nil
  end

  def default_mimetype(media_key)
    case media_key
    when 'imageMessage' then 'image/jpeg'
    when 'stickerMessage' then 'image/webp'
    when 'audioMessage' then 'audio/ogg'
    when 'videoMessage' then 'video/mp4'
    else 'application/octet-stream'
    end
  end

  def default_extension(media_key)
    case media_key
    when 'imageMessage' then 'jpg'
    when 'stickerMessage' then 'webp'
    when 'audioMessage' then 'ogg'
    when 'videoMessage' then 'mp4'
    else 'bin'
    end
  end
end
